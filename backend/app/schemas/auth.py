from datetime import date
from typing import Optional

from pydantic import BaseModel

from ..models.user import UserRole


class RegisterRequest(BaseModel):
    name: str
    email: str
    password: str
    age: Optional[int] = None
    date_of_birth: Optional[date] = None
    role: UserRole = UserRole.student
    parent_email: Optional[str] = None
    class_name: Optional[str] = None
    school_name: Optional[str] = None
    location: Optional[str] = None
    phone: Optional[str] = None
    requested_role: Optional[str] = None
    recaptcha_token: Optional[str] = None


class LoginRequest(BaseModel):
    email: str
    password: str
    recaptcha_token: Optional[str] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    roles: list[str] = []   # all roles the user holds
    user_id: int
    name: str
    access_status: Optional[str] = None


class TokenData(BaseModel):
    sub: str    # user_id as string
    role: str
    jti: str


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    email: str
    otp: str
    new_password: str
