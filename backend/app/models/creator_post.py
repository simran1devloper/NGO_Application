from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import relationship

from ..database import Base


class CreatorPost(Base):
    __tablename__ = "creator_posts"

    id = Column(Integer, primary_key=True, index=True)
    post_type = Column(String, nullable=False)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=False)
    category = Column(String, nullable=False)
    image_url = Column(String, nullable=True)
    attached_course_id = Column(Integer, ForeignKey("courses.id"), nullable=True)
    attached_event_id = Column(Integer, ForeignKey("events.id"), nullable=True)
    attached_quiz_id = Column(Integer, ForeignKey("quizzes.id"), nullable=True)
    visibility = Column(String, nullable=False, default="all_students")
    status = Column(String, nullable=False, default="draft")
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    # ── maker-checker approval fields ─────────────────────────────────────────
    approved_by      = Column(Integer, ForeignKey("users.id"), nullable=True)
    approved_at      = Column(DateTime, nullable=True)
    rejection_reason = Column(String, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    creator  = relationship("User", foreign_keys=[created_by])
    approver = relationship("User", foreign_keys=[approved_by])
    attached_course = relationship("Course", foreign_keys=[attached_course_id])
    attached_event = relationship("Event", foreign_keys=[attached_event_id])
    attached_quiz = relationship("Quiz", foreign_keys=[attached_quiz_id])
