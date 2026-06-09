import enum

from sqlalchemy import (
    Boolean, Column, DateTime, ForeignKey, Integer, String, Text,
    UniqueConstraint, func,
)
from sqlalchemy.orm import relationship

from ..database import Base


class ReviewTargetType(str, enum.Enum):
    course  = "course"
    mentor  = "mentor"
    post    = "post"
    event   = "event"


class ReviewStatus(str, enum.Enum):
    pending  = "pending"    # awaiting mediator approval
    approved = "approved"
    rejected = "rejected"


class Review(Base):
    """
    User-written star rating + text for a course, mentor, post, or event.
    One review per (user, target_type, target_id). Requires mediator approval
    before it appears publicly.
    """

    __tablename__ = "reviews"

    id               = Column(Integer, primary_key=True, index=True)
    user_id          = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    target_type      = Column(String, nullable=False)    # ReviewTargetType value
    target_id        = Column(Integer, nullable=False)
    rating           = Column(Integer, nullable=False)   # 1–5
    title            = Column(String(200), nullable=True)
    body             = Column(Text, nullable=False)
    status           = Column(String, default=ReviewStatus.pending.value, nullable=False)
    rejection_reason = Column(Text, nullable=True)
    reviewed_by      = Column(Integer, ForeignKey("users.id"), nullable=True)
    reviewed_at      = Column(DateTime, nullable=True)
    is_edited        = Column(Boolean, default=False, nullable=False)
    created_at       = Column(DateTime, server_default=func.now())
    updated_at       = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        UniqueConstraint("user_id", "target_type", "target_id", name="uq_review_per_target"),
    )

    author     = relationship("User", foreign_keys=[user_id])
    moderator  = relationship("User", foreign_keys=[reviewed_by])
