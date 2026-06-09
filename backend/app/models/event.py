import enum

from sqlalchemy import (
    Boolean, Column, DateTime, Enum as SAEnum, Float, ForeignKey,
    Integer, String, Text, UniqueConstraint, func,
)
from sqlalchemy.orm import relationship

from ..database import Base


class EventType(str, enum.Enum):
    quiz = "quiz"
    talent_hunt = "talent_hunt"
    daily_challenge = "daily_challenge"
    counselling_drive = "counselling_drive"
    scholarship = "scholarship"
    awareness_campaign = "awareness_campaign"
    workshop = "workshop"
    competition = "competition"
    cyber_security = "cyber_security"


class EventStatus(str, enum.Enum):
    draft = "draft"
    pending_review = "pending_review"
    published = "published"
    registration_open = "registration_open"
    live = "live"
    evaluation = "evaluation"
    selection = "selection"
    completed = "completed"
    archived = "archived"


class SelectionMethod(str, enum.Enum):
    lucky_draw = "lucky_draw"
    manual = "manual"
    hybrid = "hybrid"
    score_based = "score_based"


class Event(Base):
    __tablename__ = "events"

    id                     = Column(Integer, primary_key=True, index=True)
    title                  = Column(String, nullable=False)
    subtitle               = Column(String, nullable=True)
    description            = Column(Text, nullable=True)
    event_type             = Column(SAEnum(EventType), nullable=False)
    quiz_id                = Column(Integer, ForeignKey("quizzes.id"), nullable=True)
    is_daily_challenge     = Column(Boolean, default=False, nullable=False)
    status                 = Column(SAEnum(EventStatus), default=EventStatus.draft, nullable=False)
    created_by             = Column(Integer, ForeignKey("users.id"), nullable=False)
    banner_url             = Column(String, nullable=True)
    thumbnail_url          = Column(String, nullable=True)
    theme_color            = Column(String, default="#41A7F5", nullable=False)
    age_min                = Column(Integer, nullable=True)
    age_max                = Column(Integer, nullable=True)
    min_quiz_score         = Column(Float, nullable=True)
    required_challenges    = Column(Integer, default=0, nullable=False)
    max_participants       = Column(Integer, nullable=True)
    selection_method       = Column(SAEnum(SelectionMethod), default=SelectionMethod.lucky_draw, nullable=False)
    max_selections         = Column(Integer, nullable=True)
    counselling_enabled    = Column(Boolean, default=False, nullable=False)
    certificate_enabled    = Column(Boolean, default=False, nullable=False)
    scholarship_enabled    = Column(Boolean, default=False, nullable=False)
    mentorship_enabled     = Column(Boolean, default=False, nullable=False)
    auto_publish           = Column(Boolean, default=False, nullable=False)
    auto_close             = Column(Boolean, default=False, nullable=False)
    auto_result_publish    = Column(Boolean, default=False, nullable=False)
    auto_notification      = Column(Boolean, default=True, nullable=False)
    push_notification      = Column(Boolean, default=True, nullable=False)
    in_app_notification    = Column(Boolean, default=True, nullable=False)
    email_notification     = Column(Boolean, default=False, nullable=False)
    registration_start     = Column(DateTime, nullable=True)
    registration_end       = Column(DateTime, nullable=True)
    event_start            = Column(DateTime, nullable=True)
    event_end              = Column(DateTime, nullable=True)
    start_date             = Column(DateTime, nullable=True)
    end_date               = Column(DateTime, nullable=True)
    result_date            = Column(DateTime, nullable=True)
    counselling_date       = Column(DateTime, nullable=True)
    # ── maker-checker approval fields ─────────────────────────────────────────
    approved_by      = Column(Integer, ForeignKey("users.id"), nullable=True)
    approved_at      = Column(DateTime, nullable=True)
    rejection_reason = Column(String, nullable=True)
    created_at             = Column(DateTime, server_default=func.now())
    updated_at             = Column(DateTime, server_default=func.now())

    # Relationships
    creator      = relationship("User", foreign_keys=[created_by])
    approver     = relationship("User", foreign_keys=[approved_by])
    participants = relationship(
        "EventParticipant", back_populates="event",
        cascade="all, delete-orphan",
    )
    slots        = relationship(
        "EventSlot", back_populates="event",
        cascade="all, delete-orphan",
        order_by="EventSlot.starts_at",
    )
    quizzes      = relationship(
        "EventQuiz", back_populates="event",
        cascade="all, delete-orphan",
    )
    selections   = relationship(
        "EventSelection", back_populates="event",
        cascade="all, delete-orphan",
    )

    @property
    def participant_count(self) -> int:
        return len(self.participants)


class EventParticipant(Base):
    __tablename__ = "event_participants"

    __table_args__ = (UniqueConstraint("event_id", "user_id"),)

    id            = Column(Integer, primary_key=True, index=True)
    event_id      = Column(Integer, ForeignKey("events.id"), nullable=False)
    user_id       = Column(Integer, ForeignKey("users.id"), nullable=False)
    slot_id       = Column(Integer, ForeignKey("event_slots.id"), nullable=True)
    score         = Column(Float, default=0.0, nullable=False)
    status        = Column(String, default="registered", nullable=False)
    registered_at = Column(DateTime, server_default=func.now())

    event = relationship("Event", back_populates="participants")
    user  = relationship("User", foreign_keys=[user_id])
    slot  = relationship("EventSlot", back_populates="participants")


class EventSlot(Base):
    __tablename__ = "event_slots"

    id         = Column(Integer, primary_key=True, index=True)
    event_id   = Column(Integer, ForeignKey("events.id"), nullable=False)
    title      = Column(String, nullable=False)
    starts_at  = Column(DateTime, nullable=False)
    ends_at    = Column(DateTime, nullable=True)
    capacity   = Column(Integer, nullable=False, default=1)
    created_at = Column(DateTime, server_default=func.now())

    event = relationship("Event", back_populates="slots")
    participants = relationship("EventParticipant", back_populates="slot")

    @property
    def booked_count(self) -> int:
        return len(self.participants)

    @property
    def available_count(self) -> int:
        return max(0, self.capacity - self.booked_count)


class EventQuiz(Base):
    __tablename__ = "event_quizzes"

    id         = Column(Integer, primary_key=True, index=True)
    event_id   = Column(Integer, ForeignKey("events.id"), nullable=False)
    quiz_title = Column(String, nullable=False)
    quiz_id    = Column(Integer, nullable=True)
    is_primary = Column(Boolean, default=True, nullable=False)

    event = relationship("Event", back_populates="quizzes")


class EventSelection(Base):
    __tablename__ = "event_selections"

    id                   = Column(Integer, primary_key=True, index=True)
    event_id             = Column(Integer, ForeignKey("events.id"), nullable=False)
    user_id              = Column(Integer, ForeignKey("users.id"), nullable=False)
    selected_by          = Column(Integer, ForeignKey("users.id"), nullable=True)
    selection_method     = Column(String, nullable=False)
    counselling_assigned = Column(Boolean, default=False, nullable=False)
    selected_at          = Column(DateTime, server_default=func.now())
    selection_note       = Column(Text, nullable=True)

    event    = relationship("Event", back_populates="selections")
    user     = relationship("User", foreign_keys=[user_id])
    selector = relationship("User", foreign_keys=[selected_by])


class QuizMapping(Base):
    __tablename__ = "quiz_mappings"

    id             = Column(Integer, primary_key=True, index=True)
    event_id       = Column(Integer, ForeignKey("events.id"), nullable=False)
    quiz_id        = Column(Integer, ForeignKey("quizzes.id"), nullable=False)
    challenge_type = Column(String, nullable=False)
    sync_status    = Column(String, default="synced", nullable=False)
    created_at     = Column(DateTime, server_default=func.now())

    __table_args__ = (UniqueConstraint("event_id", "quiz_id"),)
