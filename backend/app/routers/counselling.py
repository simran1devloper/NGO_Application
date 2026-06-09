from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..crud import counselling_crud
from ..database import get_db
from ..dependencies import admin_only, get_current_user, mentor_or_above, require_role
from ..google_calendar import get_authorization_url, is_calendar_authorized
from ..models.user import User, UserRole
from ..schemas.counselling import (
    CounsellingAnalyticsResponse,
    MentorProfileCreate,
    MentorProfileResponse,
    MentorProfileUpdate,
)
from ..schemas.wellness import CounsellingSlotResponse

router = APIRouter(prefix="/counselling", tags=["Counselling"])


# ── Mentor Profiles ────────────────────────────────────────────────────────────

@router.get("/mentors", response_model=list[MentorProfileResponse],
            summary="List active mentor profiles [authenticated]")
def list_mentors(
    category: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return counselling_crud.list_mentors(db, category=category)


@router.get("/mentors/{mentor_id}", response_model=MentorProfileResponse,
            summary="Get mentor profile detail [authenticated]")
def get_mentor(
    mentor_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = counselling_crud.get_mentor(db, mentor_id)
    if not profile:
        raise HTTPException(status_code=404, detail="Mentor profile not found")
    return profile


@router.post("/mentors", response_model=MentorProfileResponse, status_code=201,
             summary="Create mentor profile [admin only]")
def create_mentor_profile(
    payload: MentorProfileCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(admin_only),
):
    # Payload must target a user; use current_user.id or allow specifying user_id
    existing = counselling_crud.get_mentor_by_user(db, current_user.id)
    if existing:
        raise HTTPException(status_code=409, detail="Mentor profile already exists for this user")
    return counselling_crud.create_mentor_profile(db, current_user.id, payload)


@router.post("/mentors/for-user/{user_id}", response_model=MentorProfileResponse, status_code=201,
             summary="Create mentor profile for a specific user [admin only]")
def create_mentor_profile_for_user(
    user_id: int,
    payload: MentorProfileCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(admin_only),
):
    existing = counselling_crud.get_mentor_by_user(db, user_id)
    if existing:
        raise HTTPException(status_code=409, detail="Mentor profile already exists for this user")
    return counselling_crud.create_mentor_profile(db, user_id, payload)


@router.patch("/mentors/{mentor_id}", response_model=MentorProfileResponse,
              summary="Update mentor profile [admin or the mentor themselves]")
def update_mentor_profile(
    mentor_id: int,
    payload: MentorProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = counselling_crud.get_mentor(db, mentor_id)
    if not profile:
        raise HTTPException(status_code=404, detail="Mentor profile not found")
    # Only admin/super_admin or the owning mentor may update a mentor profile.
    # content_creator is intentionally excluded — creating/editing mentors is
    # an administrative operation, not a content-management task.
    is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
    is_owner = (current_user.role == UserRole.mentor and profile.user_id == current_user.id)
    if not is_admin and not is_owner:
        raise HTTPException(status_code=403, detail="Access denied")
    updated = counselling_crud.update_mentor_profile(db, mentor_id, payload)
    return updated


# ── Slots ──────────────────────────────────────────────────────────────────────

@router.get("/slots", response_model=list[CounsellingSlotResponse],
            summary="List all available counselling slots [authenticated]")
def list_slots(
    category: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return counselling_crud.list_all_available_slots(db, category=category)


@router.get("/slots/mentor/{user_id}", response_model=list[CounsellingSlotResponse],
            summary="List slots for a specific mentor [authenticated]")
def list_mentor_slots(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return counselling_crud.list_slots_by_user(db, user_id)


# ── Analytics ─────────────────────────────────────────────────────────────────

@router.get("/analytics", response_model=CounsellingAnalyticsResponse,
            summary="Booking analytics summary [mentor, admin, super_admin]")
def get_analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(mentor_or_above),
):
    return counselling_crud.get_analytics(db)


# ── Google Calendar / Meet status ─────────────────────────────────────────────

@router.get("/calendar/meet-status",
            summary="Google Calendar + Meet authorization status [admin, mentor]")
def meet_status(
    current_user: User = Depends(
        require_role(UserRole.admin, UserRole.super_admin, UserRole.mentor)
    ),
):
    """
    Returns whether the server is authorized to auto-create Google Meet links.
    If not authorized, returns the URL the admin must visit to connect.
    """
    authorized = is_calendar_authorized()
    if authorized:
        return {
            "authorized": True,
            "message": "Google Calendar is connected. Meet links are auto-generated when slots are created or sessions are booked.",
        }
    try:
        auth_url, _ = get_authorization_url()
    except Exception:
        auth_url = None
    return {
        "authorized": False,
        "message": "Google Calendar is not connected. An admin must authorize the app once.",
        "setup_url": "/auth/google/calendar/authorize",
        "authorization_url": auth_url,
        "instructions": (
            "1. Open authorization_url in a browser. "
            "2. Sign in with the Google account that will host all Meet calls. "
            "3. You will be redirected back automatically. "
            "4. After authorization, all new slots and bookings will get Meet links."
        ),
    }
