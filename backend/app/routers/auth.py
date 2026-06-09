import logging
import random
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from google.auth.exceptions import GoogleAuthError
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..recaptcha import verify_recaptcha

logger = logging.getLogger(__name__)

from ..auth0_validator import verify_auth0_token
from ..config import settings
from ..crud.auth_crud import (
    create_access_token,
    decode_token,
    get_or_create_auth0_user,
    get_or_create_google_user,
    get_user_by_email,
    hash_password,
    register_user,
    revoke_token,
    verify_password,
)
from ..crud import reward_crud
from ..database import get_db
from ..dependencies import get_current_user, require_role
from ..google_calendar import exchange_code_for_tokens, get_authorization_url, is_calendar_authorized
from ..models.reward import RewardTrigger
from ..models.user import User, UserRole
from ..permissions import parse_roles
from ..schemas.auth import (
    ChangePasswordRequest,
    ForgotPasswordRequest,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
)
from ..schemas.user import UserResponse

router = APIRouter(prefix="/auth", tags=["Auth"])
_bearer = HTTPBearer()


@router.post("/register", status_code=201,
             summary="Register a new user account")
async def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    if payload.recaptcha_token:
        if not await verify_recaptcha(payload.recaptcha_token):
            raise HTTPException(status_code=400, detail="CAPTCHA verification failed. Please try again.")
    if get_user_by_email(db, payload.email):
        raise HTTPException(status_code=409, detail="Email already registered")
    user = register_user(db, payload)
    return {
        "message": "Registration successful. Awaiting admin approval.",
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "role": user.role.value,
            "access_status": user.access_status,
            "requested_role": user.requested_role,
        },
    }


@router.post("/login", response_model=TokenResponse,
             summary="Login and receive a JWT access token")
async def login(payload: LoginRequest, db: Session = Depends(get_db)):
    if payload.recaptcha_token:
        if not await verify_recaptcha(payload.recaptcha_token):
            raise HTTPException(status_code=400, detail="CAPTCHA verification failed. Please try again.")
    user = get_user_by_email(db, payload.email)
    if not user or not user.hashed_password:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is inactive")
    access_status = getattr(user, "access_status", "approved") or "approved"
    token = create_access_token(user)

    reward_crud.award_rule_reward(
        db, user_id=user.id,
        trigger=RewardTrigger.daily_login,
        source_type="auth", source_id=user.id,
        message="Daily login reward",
    )

    return TokenResponse(
        access_token=token,
        role=user.role.value,
        roles=[r.value for r in parse_roles(user.roles, user.role)],
        user_id=user.id,
        name=user.name,
        access_status=access_status,
    )


@router.post("/logout", status_code=204,
             summary="Revoke the current JWT (adds jti to blacklist)")
def logout(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    current_user: User = Depends(get_current_user),   # validates token first
    db: Session = Depends(get_db),
):
    payload = decode_token(credentials.credentials)
    jti = payload.get("jti", "")
    if jti:
        revoke_token(db, jti)


@router.get("/me", response_model=UserResponse,
            summary="Return the profile of the currently authenticated user")
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.post("/change-password", status_code=200,
             summary="Change the current user's password (all roles)")
def change_password(
    payload: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user.hashed_password:
        raise HTTPException(
            status_code=400,
            detail="Password change is not available for social-login accounts.",
        )
    if not verify_password(payload.current_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Current password is incorrect.")
    if len(payload.new_password) < 8:
        raise HTTPException(
            status_code=422,
            detail="New password must be at least 8 characters.",
        )
    current_user.hashed_password = hash_password(payload.new_password)
    db.commit()
    return {"message": "Password changed successfully."}


@router.post("/forgot-password", status_code=200,
             summary="Request a 6-digit password reset OTP (all roles)")
def forgot_password(
    payload: ForgotPasswordRequest,
    db: Session = Depends(get_db),
):
    user = get_user_by_email(db, payload.email.strip().lower())
    if user and user.hashed_password:
        otp = str(random.randint(100000, 999999))
        user.reset_token = otp
        user.reset_token_expires = datetime.now(timezone.utc) + timedelta(minutes=15)
        db.commit()
        # In production, send otp via email. Returned here for demo only.
        return {
            "message": "Reset code generated.",
            "reset_token": otp,
            "expires_in_minutes": 15,
        }
    # Don't reveal whether the email exists.
    return {
        "message": "If this email is registered with a password account, a reset code has been sent.",
        "reset_token": None,
    }


@router.post("/reset-password", status_code=200,
             summary="Reset password using the OTP (all roles)")
def reset_password(
    payload: ResetPasswordRequest,
    db: Session = Depends(get_db),
):
    user = get_user_by_email(db, payload.email.strip().lower())
    if not user or not user.reset_token:
        raise HTTPException(status_code=400, detail="Invalid or expired reset code.")
    if user.reset_token != payload.otp.strip():
        raise HTTPException(status_code=400, detail="Incorrect reset code.")
    expires = user.reset_token_expires
    if expires is None or datetime.now(timezone.utc) > expires.replace(tzinfo=timezone.utc):
        user.reset_token = None
        user.reset_token_expires = None
        db.commit()
        raise HTTPException(status_code=400, detail="Reset code has expired. Please request a new one.")
    if len(payload.new_password) < 8:
        raise HTTPException(status_code=422, detail="New password must be at least 8 characters.")
    user.hashed_password = hash_password(payload.new_password)
    user.reset_token = None
    user.reset_token_expires = None
    db.commit()
    return {"message": "Password reset successfully. You can now sign in with your new password."}


class GoogleLoginRequest(BaseModel):
    id_token: str


@router.post("/google", response_model=TokenResponse,
             summary="Sign in with — verifies the ID token and returns a CareSkill JWT")
def google_login(payload: GoogleLoginRequest, db: Session = Depends(get_db)):
    # Verify the Google ID token using google-auth (verifies JWT signature locally).
    # audience=None skips the aud check so both Android and Web client tokens are accepted;
    # set GOOGLE_CLIENT_ID in .env to restrict to your Web client ID only.
    try:
        id_info = google_id_token.verify_oauth2_token(
            payload.id_token,
            google_requests.Request(),
            audience=settings.google_client_id or None,
            clock_skew_in_seconds=10,
        )
    except (GoogleAuthError, ValueError) as exc:
        logger.warning("Google ID token verification failed: %s", exc)
        raise HTTPException(status_code=401, detail="Invalid Google token") from exc

    email: str = id_info.get("email", "")
    name: str = id_info.get("name") or email.split("@")[0]

    if not email:
        raise HTTPException(status_code=401, detail="Google token missing email")
    if not id_info.get("email_verified"):
        raise HTTPException(status_code=401, detail="Google email is not verified")

    user = get_or_create_google_user(db, email=email, name=name)

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is inactive")

    token = create_access_token(user)

    reward_crud.award_rule_reward(
        db, user_id=user.id,
        trigger=RewardTrigger.daily_login,
        source_type="auth", source_id=user.id,
        message="Daily login reward",
    )

    return TokenResponse(
        access_token=token,
        role=user.role.value,
        roles=[r.value for r in parse_roles(user.roles, user.role)],
        user_id=user.id,
        name=user.name,
    )


class Auth0LoginRequest(BaseModel):
    id_token: str


@router.post("/auth0", response_model=TokenResponse,
             summary="Sign in with Auth0 — verifies the ID token and returns a CareSkill JWT")
def auth0_login(payload: Auth0LoginRequest, db: Session = Depends(get_db)):
    if not settings.auth0_domain or not settings.auth0_client_id:
        raise HTTPException(
            status_code=503,
            detail="AUTH0_DOMAIN and AUTH0_CLIENT_ID must be set in .env first.",
        )
    try:
        id_info = verify_auth0_token(payload.id_token)
    except Exception as exc:
        logger.warning("Auth0 token verification failed: %s", exc)
        raise HTTPException(status_code=401, detail="Invalid Auth0 token") from exc

    email: str = id_info.get("email", "")
    name: str = (
        id_info.get("name")
        or id_info.get("nickname")
        or (email.split("@")[0] if email else "")
    )
    auth0_sub: str = id_info.get("sub", "")

    if not email:
        raise HTTPException(status_code=401, detail="Auth0 token missing email claim")
    if not id_info.get("email_verified", False):
        raise HTTPException(status_code=401, detail="Auth0 email is not verified")

    user = get_or_create_auth0_user(db, email=email, name=name, auth0_sub=auth0_sub)
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is inactive")

    token = create_access_token(user)

    reward_crud.award_rule_reward(
        db, user_id=user.id,
        trigger=RewardTrigger.daily_login,
        source_type="auth", source_id=user.id,
        message="Daily login reward",
    )

    return TokenResponse(
        access_token=token,
        role=user.role.value,
        roles=[r.value for r in parse_roles(user.roles, user.role)],
        user_id=user.id,
        name=user.name,
    )


# ── Google Calendar OAuth2 setup (one-time, admin only) ───────────────────────

@router.get("/google/calendar/status",
            summary="Check if Google Calendar is authorized [admin]")
def calendar_status(
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
):
    authorized = is_calendar_authorized()
    return {
        "authorized": authorized,
        "message": (
            "Google Calendar is connected. Meet links are auto-generated."
            if authorized
            else "Not authorized. Visit /auth/google/calendar/authorize to connect."
        ),
    }


@router.get("/google/calendar/authorize",
            summary="Start Google Calendar OAuth2 consent flow [admin]")
def calendar_authorize(
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
):
    if not settings.google_client_id or not settings.google_client_secret:
        raise HTTPException(
            status_code=503,
            detail="GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be set in .env first.",
        )
    url, state = get_authorization_url()
    return {
        "authorization_url": url,
        "instructions": "Open authorization_url in a browser. Sign in with the Google account "
                        "that will host all Meet calls. You will be redirected back automatically.",
    }


@router.get("/google/callback",
            summary="OAuth2 redirect — exchanges code for Calendar tokens (no auth required)",
            include_in_schema=False)
def google_oauth_callback(code: str, state: str):
    try:
        exchange_code_for_tokens(code, state)
    except Exception as exc:
        logger.error("Calendar token exchange failed: %s", exc)
        raise HTTPException(status_code=400, detail=f"Token exchange failed: {exc}") from exc
    return {"message": "Google Calendar authorized successfully. You can close this tab."}
