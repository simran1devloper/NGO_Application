from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, Text, func
from sqlalchemy.orm import relationship

from ..database import Base


class Comment(Base):
    """Comments on creator posts. parent_id enables one level of replies."""

    __tablename__ = "comments"

    id          = Column(Integer, primary_key=True, index=True)
    post_id     = Column(Integer, ForeignKey("creator_posts.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id     = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    parent_id   = Column(Integer, ForeignKey("comments.id", ondelete="CASCADE"), nullable=True)
    body        = Column(Text, nullable=False)
    is_edited   = Column(Boolean, default=False, nullable=False)
    is_deleted  = Column(Boolean, default=False, nullable=False)    # soft-delete by author
    # ── moderation fields (mediator / admin) ──────────────────────────────────
    flag_count  = Column(Integer, default=0, nullable=False)        # incremented by reporters
    is_flagged  = Column(Boolean, default=False, nullable=False)    # True once flag_count >= threshold
    is_hidden   = Column(Boolean, default=False, nullable=False)    # hidden by mediator/admin
    hidden_by   = Column(Integer, ForeignKey("users.id"), nullable=True)
    hidden_reason = Column(Text, nullable=True)
    created_at  = Column(DateTime, server_default=func.now())
    updated_at  = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user    = relationship("User", foreign_keys=[user_id])
    hider   = relationship("User", foreign_keys=[hidden_by])
    post    = relationship("CreatorPost")
    replies = relationship(
        "Comment",
        foreign_keys=[parent_id],
        back_populates="parent",
        cascade="all, delete-orphan",
    )
    parent  = relationship("Comment", foreign_keys=[parent_id], back_populates="replies", remote_side=[id])
