import enum

from sqlalchemy import Boolean, Column, Date, DateTime, Enum as SAEnum, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import relationship

from ..database import Base


class RewardTrigger(str, enum.Enum):
    # ── gifting ───────────────────────────────────────────────────────────────
    gift = "gift"

    # ── student learning ──────────────────────────────────────────────────────
    lesson_completed    = "lesson_completed"
    video_completed     = "video_completed"
    course_completed    = "course_completed"
    topic_completed     = "topic_completed"
    quiz_passed         = "quiz_passed"         # student passes any quiz
    event_attended      = "event_attended"      # student registers for an event
    counselling_booked  = "counselling_booked"  # student books a session

    # ── content creator / mentor creation ─────────────────────────────────────
    lesson_created      = "lesson_created"      # new lesson published
    course_created      = "course_created"      # new course created
    resource_uploaded   = "resource_uploaded"   # file/resource attached to lesson
    post_approved       = "post_approved"       # creator post approved by mediator
    event_published     = "event_published"     # event published (creator/event_mgr)

    # ── mentor engagement ─────────────────────────────────────────────────────
    session_conducted   = "session_conducted"   # counselling session completed

    # ── tasks & progress ──────────────────────────────────────────────────────
    task_progress  = "task_progress"
    task_completed = "task_completed"

    # ── gamification / streaks ────────────────────────────────────────────────
    daily_login      = "daily_login"       # first login of each day
    streak_milestone = "streak_milestone"  # 7, 14, 30, 60, 100-day streak hit

    # ── milestones ────────────────────────────────────────────────────────────
    xp_milestone = "xp_milestone"  # 100, 500, 1000, 5000 XP reached

    # ── manual / admin ────────────────────────────────────────────────────────
    manual = "manual"


class RewardTransaction(Base):
    __tablename__ = "reward_transactions"

    id          = Column(Integer, primary_key=True, index=True)
    user_id     = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    actor_id    = Column(Integer, ForeignKey("users.id"), nullable=True)
    points      = Column(Integer, nullable=False)
    xp          = Column(Integer, nullable=False, default=0)
    trigger     = Column(SAEnum(RewardTrigger), nullable=False)
    title       = Column(String, nullable=False)
    message     = Column(Text, nullable=True)
    source_type = Column(String, nullable=True)
    source_id   = Column(Integer, nullable=True)
    created_at  = Column(DateTime, server_default=func.now())

    user  = relationship("User", foreign_keys=[user_id])
    actor = relationship("User", foreign_keys=[actor_id])


class RewardRule(Base):
    __tablename__ = "reward_rules"

    id          = Column(Integer, primary_key=True, index=True)
    role        = Column(String, nullable=False, default="student")
    trigger     = Column(SAEnum(RewardTrigger), nullable=False)
    points      = Column(Integer, nullable=False, default=0)
    xp          = Column(Integer, nullable=False, default=0)
    title       = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    is_active   = Column(Boolean, nullable=False, default=True)
    created_at  = Column(DateTime, server_default=func.now())


class RewardTask(Base):
    __tablename__ = "reward_tasks"

    id            = Column(Integer, primary_key=True, index=True)
    user_id       = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_by    = Column(Integer, ForeignKey("users.id"), nullable=True)
    title         = Column(String, nullable=False)
    description   = Column(Text, nullable=True)
    target_count  = Column(Integer, nullable=False, default=1)
    current_count = Column(Integer, nullable=False, default=0)
    reward_points = Column(Integer, nullable=False, default=0)
    reward_xp     = Column(Integer, nullable=False, default=0)
    status        = Column(String, nullable=False, default="active")
    due_at        = Column(DateTime, nullable=True)
    completed_at  = Column(DateTime, nullable=True)
    created_at    = Column(DateTime, server_default=func.now())

    user    = relationship("User", foreign_keys=[user_id])
    creator = relationship("User", foreign_keys=[created_by])


class UserStreak(Base):
    """Tracks consecutive-day activity per user. Updated on each meaningful action."""
    __tablename__ = "user_streaks"

    id                 = Column(Integer, primary_key=True, index=True)
    user_id            = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    current_streak     = Column(Integer, nullable=False, default=1)
    longest_streak     = Column(Integer, nullable=False, default=1)
    last_activity_date = Column(Date, nullable=True)
    total_active_days  = Column(Integer, nullable=False, default=1)

    user = relationship("User", foreign_keys=[user_id])


class UserMilestone(Base):
    """One-time achievements per user. milestone_key is unique per user."""
    __tablename__ = "user_milestones"

    id            = Column(Integer, primary_key=True, index=True)
    user_id       = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    milestone_key = Column(String, nullable=False)   # e.g. "lessons_10", "xp_500"
    title         = Column(String, nullable=False)
    description   = Column(Text, nullable=True)
    points        = Column(Integer, nullable=False, default=0)
    xp            = Column(Integer, nullable=False, default=0)
    achieved_at   = Column(DateTime, server_default=func.now())

    __table_args__ = (UniqueConstraint("user_id", "milestone_key", name="uq_user_milestone"),)

    user = relationship("User", foreign_keys=[user_id])
