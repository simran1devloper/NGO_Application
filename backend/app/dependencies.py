"""
FastAPI dependency factories for authentication and role-based access control.

Role model:
  admin → super_admin is hierarchical.
  content_creator, mentor, and mediator are feature roles.

Feature roles do not inherit from each other. A user gets combined access by
holding multiple roles, for example ["mediator", "content_creator"].

Usage in routers:
  # Any authenticated user:
  current_user: User = Depends(get_current_user)

  # Feature or admin role:
  _: User = Depends(require_role(UserRole.mentor))

  # Named permission check:
  _: User = Depends(require_permission(Permission.MANAGE_USERS))

  # Self or admin (inline ownership check):
  if current_user.id != target_id and current_user.role not in (
      UserRole.admin, UserRole.super_admin
  ):
      raise HTTPException(403, "Access denied")
"""

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy.orm import Session

from .crud.auth_crud import decode_token, is_token_revoked
from .database import get_db
from .models.user import User, UserRole
from .permissions import ADMIN_ROLES, ROLE_HIERARCHY, ROLE_PERMISSIONS, Permission, parse_roles

_bearer = HTTPBearer(auto_error=False)


# ── authentication ─────────────────────────────────────────────────────────────

def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    """Validate JWT, check blacklist, return the authenticated User (raises 401 otherwise)."""
    if not credentials:
        raise HTTPException(status_code=401, detail="Not authenticated")
    try:
        payload = decode_token(credentials.credentials)
        user_id = int(payload["sub"])
        jti     = payload.get("jti", "")
    except (JWTError, KeyError, ValueError):
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    if is_token_revoked(db, jti):
        raise HTTPException(status_code=401, detail="Token has been revoked — please log in again")

    user = db.query(User).filter(User.id == user_id, User.is_active.is_(True)).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found or account inactive")
    return user


def get_optional_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User | None:
    """Like get_current_user but returns None when unauthenticated (for semi-public endpoints)."""
    if not credentials:
        return None
    try:
        payload = decode_token(credentials.credentials)
        user_id = int(payload["sub"])
        jti     = payload.get("jti", "")
    except Exception:
        return None
    if is_token_revoked(db, jti):
        return None
    return db.query(User).filter(User.id == user_id, User.is_active.is_(True)).first()


# ── role helpers ───────────────────────────────────────────────────────────────

def _role_level(role: UserRole) -> int:
    """Return the privilege level of a role (higher = more privileged)."""
    try:
        return ROLE_HIERARCHY.index(role)
    except ValueError:
        return -1


def user_roles(user: User) -> list[UserRole]:
    """Return every role held by a user, including the primary role."""
    return parse_roles(user.roles, user.role)


def _has_allowed_role(current_user: User, allowed: tuple[UserRole, ...]) -> bool:
    roles = set(user_roles(current_user))
    allowed_set = set(allowed)

    if roles & allowed_set:
        return True

    # Only admin roles inherit down into feature areas.
    if roles & ADMIN_ROLES and not allowed_set.isdisjoint(set(UserRole)):
        return True

    return False


# ── dependency factories ───────────────────────────────────────────────────────

def require_role(*allowed: UserRole):
    """
    Dependency factory that enforces role-based access.

    Non-admin roles are feature grants: a user must explicitly hold one of the
    requested roles. Admin and super_admin are hierarchical management roles and
    satisfy feature-role guards.

    Raises HTTP 403 when the caller does not hold any required role.
    """
    if not allowed:
        raise ValueError("require_role() called with no roles")

    def _guard(current_user: User = Depends(get_current_user)) -> User:
        if _has_allowed_role(current_user, allowed):
            return current_user
        raise HTTPException(
            status_code=403,
            detail=f"Access denied. Required role(s): {[r.value for r in allowed]}",
        )
    return _guard


def require_permission(permission: Permission):
    """
    Dependency factory that enforces a named permission.

    Checks the union of ROLE_PERMISSIONS for every role the caller holds.
    """
    def _guard(current_user: User = Depends(get_current_user)) -> User:
        roles = user_roles(current_user)
        if any(permission in ROLE_PERMISSIONS.get(role, frozenset()) for role in roles):
            return current_user
        raise HTTPException(
            status_code=403,
            detail=f"Access denied. Required permission: {permission.value}",
        )
    return _guard


# ── convenience aliases ────────────────────────────────────────────────────────

def admin_only(
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
) -> User:
    return current_user


def mentor_or_above(
    current_user: User = Depends(
        require_role(UserRole.mentor, UserRole.admin, UserRole.super_admin)
    ),
) -> User:
    return current_user


def content_creator_or_above(
    current_user: User = Depends(
        require_role(UserRole.content_creator, UserRole.mentor, UserRole.admin, UserRole.super_admin)
    ),
) -> User:
    return current_user


def non_student(
    current_user: User = Depends(
        require_role(UserRole.content_creator, UserRole.mentor, UserRole.admin, UserRole.super_admin)
    ),
) -> User:
    return current_user


def mediator_or_above(
    current_user: User = Depends(
        require_role(UserRole.mediator, UserRole.admin, UserRole.super_admin)
    ),
) -> User:
    return current_user
