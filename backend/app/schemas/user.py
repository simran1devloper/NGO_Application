import json
from datetime import date, datetime
from typing import Any, Optional

from pydantic import BaseModel, model_validator

from ..models.user import UserRole


class UserCreate(BaseModel):
    name: str
    age: Optional[int] = None
    date_of_birth: Optional[date] = None
    role: UserRole = UserRole.student
    parent_email: Optional[str] = None
    class_name: Optional[str] = None
    school_name: Optional[str] = None
    location: Optional[str] = None
    phone: Optional[str] = None


class UserUpdate(BaseModel):
    name: Optional[str] = None
    age: Optional[int] = None
    date_of_birth: Optional[date] = None
    parent_email: Optional[str] = None
    class_name: Optional[str] = None
    school_name: Optional[str] = None
    location: Optional[str] = None
    phone: Optional[str] = None


class UserRoleUpdate(BaseModel):
    role: UserRole


class UserStatusUpdate(BaseModel):
    is_active: bool


class XPAdd(BaseModel):
    amount: int


class UserResponse(BaseModel):
    id: int
    name: str
    email: Optional[str] = None
    age: Optional[int] = None
    date_of_birth: Optional[date] = None
    level: int
    xp: int
    role: str = "student"
    roles: list[str] = []
    access_status: str = "pending_verification"
    is_active: bool = True
    parent_email: Optional[str] = None
    class_name: Optional[str] = None
    school_name: Optional[str] = None
    location: Optional[str] = None
    phone: Optional[str] = None
    requested_role: Optional[str] = None
    verification_note: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}

    @model_validator(mode="before")
    @classmethod
    def coerce_roles(cls, data: Any) -> Any:
        if hasattr(data, "__dict__"):
            raw = getattr(data, "roles", None)
            role = getattr(data, "role", None)
        elif isinstance(data, dict):
            raw = data.get("roles")
            role = data.get("role")
        else:
            return data
        if isinstance(raw, str):
            try:
                parsed = json.loads(raw)
            except (ValueError, TypeError):
                parsed = [role.value if hasattr(role, "value") else str(role)] if role else []
        elif isinstance(raw, list):
            parsed = raw
        else:
            parsed = [role.value if hasattr(role, "value") else str(role)] if role else []
        if isinstance(data, dict):
            data["roles"] = parsed
        else:
            object.__setattr__(data, "roles", parsed) if hasattr(data, "__dict__") else None
        return data


class UserStats(BaseModel):
    user_id: int
    weekly_learning_hours: float
    skill_growth_percent: int
    quiz_rank: int
    courses_enrolled: int = 0
    lessons_completed: int = 0
    study_streak_days: int = 0


class LeaderboardEntry(BaseModel):
    rank: int
    user_id: int
    name: str
    xp: int
    level: int
