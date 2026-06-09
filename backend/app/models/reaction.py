import enum

from sqlalchemy import Column, DateTime, Enum as SAEnum, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import relationship

from ..database import Base


class ReactionType(str, enum.Enum):
    like     = "like"
    dislike  = "dislike"
    upvote   = "upvote"
    downvote = "downvote"


class TargetType(str, enum.Enum):
    post   = "post"
    course = "course"
    event  = "event"
    comment = "comment"


class Reaction(Base):
    """One row per (user, target_type, target_id). Toggling the same reaction
    removes it; switching to the opposite reaction updates it in place."""

    __tablename__ = "reactions"
    __table_args__ = (
        UniqueConstraint("user_id", "target_type", "target_id", name="uq_reaction"),
    )

    id            = Column(Integer, primary_key=True, index=True)
    user_id       = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    target_type   = Column(SAEnum(TargetType), nullable=False)
    target_id     = Column(Integer, nullable=False, index=True)
    reaction_type = Column(SAEnum(ReactionType), nullable=False)
    created_at    = Column(DateTime, server_default=func.now())

    user = relationship("User")
