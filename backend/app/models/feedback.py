import enum

from sqlalchemy import Column, DateTime, Enum as SAEnum, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import relationship

from ..database import Base


class FeedbackCategory(str, enum.Enum):
    general    = "general"
    course     = "course"
    mentor     = "mentor"
    event      = "event"
    platform   = "platform"
    suggestion = "suggestion"


class FeedbackStatus(str, enum.Enum):
    open     = "open"
    reviewed = "reviewed"
    resolved = "resolved"


class Feedback(Base):
    __tablename__ = "feedbacks"

    id          = Column(Integer, primary_key=True, index=True)
    user_id     = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    name        = Column(String, nullable=False)
    email       = Column(String, nullable=True)
    category    = Column(SAEnum(FeedbackCategory), default=FeedbackCategory.general, nullable=False)
    rating      = Column(Integer, nullable=True)        # 1-5, nullable for non-rating feedback
    subject     = Column(String, nullable=False)
    message     = Column(Text, nullable=False)
    status      = Column(SAEnum(FeedbackStatus), default=FeedbackStatus.open, nullable=False)
    admin_reply = Column(Text, nullable=True)
    reference_id = Column(Integer, nullable=True)       # course_id / event_id / mentor_id
    created_at  = Column(DateTime, server_default=func.now())
    updated_at  = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User")
