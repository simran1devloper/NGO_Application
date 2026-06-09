from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from ..models.feedback import FeedbackCategory, FeedbackStatus


class FeedbackCreate(BaseModel):
    name:        str
    email:       Optional[str] = None
    category:    FeedbackCategory = FeedbackCategory.general
    rating:      Optional[int] = Field(None, ge=1, le=5)
    subject:     str
    message:     str
    reference_id: Optional[int] = None


class FeedbackReply(BaseModel):
    admin_reply: str
    status:      FeedbackStatus = FeedbackStatus.reviewed


class FeedbackResponse(BaseModel):
    id:           int
    user_id:      Optional[int]
    name:         str
    email:        Optional[str]
    category:     FeedbackCategory
    rating:       Optional[int]
    subject:      str
    message:      str
    status:       FeedbackStatus
    admin_reply:  Optional[str]
    reference_id: Optional[int]
    created_at:   datetime

    class Config:
        from_attributes = True
