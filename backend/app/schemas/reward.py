from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field

from ..models.reward import RewardTrigger


class RewardTransactionResponse(BaseModel):
    id: int
    user_id: int
    actor_id: Optional[int] = None
    points: int
    xp: int
    trigger: RewardTrigger
    title: str
    message: Optional[str] = None
    source_type: Optional[str] = None
    source_id: Optional[int] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class RewardSummaryResponse(BaseModel):
    user_id: int
    total_points: int
    total_xp_from_rewards: int
    rewards: list[RewardTransactionResponse]


class RewardGiftCreate(BaseModel):
    recipient_id: int
    points: int = Field(gt=0, le=1000)
    title: str = "Gift reward"
    message: Optional[str] = None


class RewardRuleCreate(BaseModel):
    role: str = "student"
    trigger: RewardTrigger
    points: int = Field(ge=0, le=10000)
    xp: int = Field(ge=0, le=10000)
    title: str
    description: Optional[str] = None
    is_active: bool = True


class RewardRuleUpdate(BaseModel):
    points: Optional[int] = Field(default=None, ge=0, le=10000)
    xp: Optional[int] = Field(default=None, ge=0, le=10000)
    title: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = None


class RewardRuleResponse(BaseModel):
    id: int
    role: str
    trigger: RewardTrigger
    points: int
    xp: int
    title: str
    description: Optional[str] = None
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class RewardTaskCreate(BaseModel):
    user_id: int
    title: str
    description: Optional[str] = None
    target_count: int = Field(default=1, ge=1, le=1000)
    reward_points: int = Field(default=0, ge=0, le=10000)
    reward_xp: int = Field(default=0, ge=0, le=10000)
    due_at: Optional[datetime] = None


class RewardTaskProgress(BaseModel):
    increment: int = Field(default=1, ge=1, le=1000)


class RewardTaskResponse(BaseModel):
    id: int
    user_id: int
    created_by: Optional[int] = None
    title: str
    description: Optional[str] = None
    target_count: int
    current_count: int
    reward_points: int
    reward_xp: int
    status: str
    due_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class UserStreakResponse(BaseModel):
    user_id: int
    current_streak: int
    longest_streak: int
    last_activity_date: Optional[date] = None
    total_active_days: int

    model_config = {"from_attributes": True}


class UserMilestoneResponse(BaseModel):
    id: int
    user_id: int
    milestone_key: str
    title: str
    description: Optional[str] = None
    points: int
    xp: int
    achieved_at: datetime

    model_config = {"from_attributes": True}
