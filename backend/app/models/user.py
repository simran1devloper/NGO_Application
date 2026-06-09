import enum

from sqlalchemy import Boolean, Column, Date, DateTime, Enum as SAEnum, Integer, String, func
from sqlalchemy.orm import relationship

from ..database import Base


class UserRole(str, enum.Enum):
    super_admin     = "super_admin"
    admin           = "admin"
    mediator        = "mediator"        # moderates content, comments, reviews
    mentor          = "mentor"
    content_creator = "content_creator"
    event_manager   = "event_manager"   # creates and manages events
    support_staff   = "support_staff"   # handles user support and safety queries
    student         = "student"
    guest           = "guest"


class User(Base):
    __tablename__ = "users"

    id              = Column(Integer, primary_key=True, index=True)
    name            = Column(String, nullable=False)
    email           = Column(String, unique=True, nullable=True, index=True)
    hashed_password = Column(String, nullable=True)
    age             = Column(Integer, nullable=True)
    date_of_birth   = Column(Date, nullable=True)
    level           = Column(Integer, default=1)
    xp              = Column(Integer, default=0)
    role            = Column(SAEnum(UserRole), default=UserRole.student, nullable=False)
    access_status   = Column(String, default="pending_verification", nullable=False)
    is_active       = Column(Boolean, default=True, nullable=False)
    parent_email    = Column(String, nullable=True)
    class_name      = Column(String, nullable=True)
    school_name     = Column(String, nullable=True)
    location        = Column(String, nullable=True)
    phone           = Column(String, nullable=True)
    roles               = Column(String, nullable=True)  # JSON list e.g. '["mentor","content_creator"]'
    requested_role      = Column(String, nullable=True)
    verification_note   = Column(String, nullable=True)
    reset_token         = Column(String, nullable=True)
    reset_token_expires = Column(DateTime, nullable=True)
    created_at          = Column(DateTime, server_default=func.now())

    course_progress     = relationship("UserCourseProgress",  back_populates="user", cascade="all, delete-orphan")
    counselling_sessions= relationship("CounsellingSession",  foreign_keys="[CounsellingSession.user_id]", back_populates="user", cascade="all, delete-orphan")
    badges              = relationship("UserBadge",           back_populates="user", cascade="all, delete-orphan")
