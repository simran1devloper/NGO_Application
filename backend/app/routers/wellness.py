from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..crud import reward_crud, wellness_crud
from ..crud.wellness_crud import delete_availability_slot
from ..database import get_db
from ..dependencies import get_current_user
from ..google_calendar import create_meet_link
from ..models.reward import RewardTrigger
from ..models.user import User, UserRole
from ..schemas.wellness import (
    CounsellingCreate,
    CounsellingResponse,
    CounsellingSlotBook,
    CounsellingSlotCreate,
    CounsellingSlotResponse,
    CounsellingSlotUpdate,
    CounsellingUpdate,
)

router = APIRouter(prefix="/users/{user_id}/wellness", tags=["Wellness"])

# ── helpers ────────────────────────────────────────────────────────────────────

def _assert_wellness_access(current_user: User, user_id: int) -> None:
    """Self, mentor, or admin may access wellness data."""
    if current_user.id != user_id and current_user.role not in (
        UserRole.mentor, UserRole.admin, UserRole.super_admin
    ):
        raise HTTPException(status_code=403, detail="Access denied")


def _assert_mentor_manager(current_user: User) -> None:
    if current_user.role not in (
        UserRole.mentor, UserRole.admin, UserRole.super_admin
    ):
        raise HTTPException(status_code=403, detail="Only mentors and admins may manage counselling slots")


# ── counselling ────────────────────────────────────────────────────────────────

@router.get("/counselling", response_model=list[CounsellingResponse],
            summary="List counselling sessions [self, mentor, admin]")
def list_counselling(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _assert_wellness_access(current_user, user_id)
    return wellness_crud.get_user_counselling_sessions(db, user_id)


@router.get("/counselling/availability", response_model=list[CounsellingSlotResponse],
            summary="List available counselling slots [authenticated]")
def list_available_slots(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _assert_wellness_access(current_user, user_id)
    return wellness_crud.list_available_slots(db)


@router.get("/counselling/mentor-slots", response_model=list[CounsellingSlotResponse],
            summary="List current mentor's counselling slots [mentor, admin]")
def list_my_slots(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _assert_mentor_manager(current_user)
    mentor_id = user_id if current_user.role in (UserRole.admin, UserRole.super_admin) else current_user.id
    return wellness_crud.list_mentor_slots(db, mentor_id)


@router.get("/counselling/mentor-sessions", response_model=list[CounsellingResponse],
            summary="List current mentor's counselling bookings [mentor, admin]")
def list_mentor_sessions(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _assert_mentor_manager(current_user)
    mentor_id = user_id if current_user.role in (UserRole.admin, UserRole.super_admin) else current_user.id
    return wellness_crud.get_mentor_sessions(db, mentor_id)


@router.post("/counselling/availability", response_model=CounsellingSlotResponse, status_code=201,
             summary="Create counselling availability [mentor, admin]")
def create_slot(
    user_id: int,
    payload: CounsellingSlotCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _assert_mentor_manager(current_user)
    if payload.ends_at <= payload.starts_at:
        raise HTTPException(status_code=422, detail="ends_at must be after starts_at")
    mentor_id = user_id if current_user.role in (UserRole.admin, UserRole.super_admin) else current_user.id
    mentor_name = current_user.name
    if mentor_id != current_user.id:
        mentor = db.query(User).filter(User.id == mentor_id).first()
        if not mentor:
            raise HTTPException(status_code=404, detail="Mentor not found")
        mentor_name = mentor.name

    # Auto-generate a Google Meet link if Calendar is authorized and no URL was provided.
    if not payload.meeting_url:
        meet_url = create_meet_link(
            title=f"CareSkill: {payload.topic or 'Counselling'} with {mentor_name}",
            starts_at=payload.starts_at,
            ends_at=payload.ends_at,
            description=f"CareSkill counselling session with mentor {mentor_name}.",
        )
        if meet_url:
            payload = payload.model_copy(update={"meeting_url": meet_url})

    return wellness_crud.create_availability_slot(db, mentor_id, mentor_name, payload)


@router.patch("/counselling/availability/{slot_id}", response_model=CounsellingSlotResponse,
              summary="Update counselling availability [mentor, admin]")
def update_slot(
    user_id: int,
    slot_id: int,
    payload: CounsellingSlotUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _assert_mentor_manager(current_user)
    if payload.starts_at and payload.ends_at and payload.ends_at <= payload.starts_at:
        raise HTTPException(status_code=422, detail="ends_at must be after starts_at")
    if current_user.role == UserRole.mentor:
        existing = wellness_crud.get_availability_slot(db, slot_id)
        if not existing:
            raise HTTPException(status_code=404, detail="Slot not found")
        if existing.mentor_id != current_user.id:
            raise HTTPException(status_code=403, detail="Access denied")
    slot = wellness_crud.update_availability_slot(db, slot_id, payload)
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found")
    return slot


@router.delete("/counselling/availability/{slot_id}", status_code=204,
               summary="Delete (or deactivate) a counselling slot [mentor, admin]")
def delete_slot(
    user_id: int,
    slot_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _assert_mentor_manager(current_user)
    slot = wellness_crud.get_availability_slot(db, slot_id)
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found")
    if current_user.role == UserRole.mentor and slot.mentor_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    delete_availability_slot(db, slot_id)


@router.post("/counselling/availability/{slot_id}/book", response_model=CounsellingResponse, status_code=201,
             summary="Book an available counselling slot [self, mentor, admin]")
def book_slot(
    user_id: int,
    slot_id: int,
    payload: CounsellingSlotBook,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _assert_wellness_access(current_user, user_id)
    slot = wellness_crud.get_availability_slot(db, slot_id)
    if not slot or not slot.is_available:
        raise HTTPException(status_code=400, detail="Slot is not available")

    # If the slot was created before Calendar was authorized, generate the link now.
    if not slot.meeting_url:
        meet_url = create_meet_link(
            title=f"CareSkill: {payload.topic or slot.topic or 'Counselling'} with {slot.mentor_name}",
            starts_at=slot.starts_at,
            ends_at=slot.ends_at,
            description=f"CareSkill counselling session with mentor {slot.mentor_name}.",
        )
        if meet_url:
            slot.meeting_url = meet_url
            db.commit()

    session = wellness_crud.book_availability_slot(db, user_id, slot_id, payload.topic)
    if not session:
        raise HTTPException(status_code=400, detail="Slot is not available")
    reward_crud.award_rule_reward(
        db, user_id=user_id,
        trigger=RewardTrigger.counselling_booked,
        source_type="counselling", source_id=session.id,
        message="Counselling session booked",
    )
    return session


@router.post("/counselling", response_model=CounsellingResponse, status_code=201,
             summary="Book a counselling session directly (no slot) [self, mentor, admin]")
def book_session(
    user_id: int,
    payload: CounsellingCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _assert_wellness_access(current_user, user_id)

    # Auto-generate Meet link if not supplied and Calendar is authorised.
    payload_data = payload.model_dump()
    if not payload_data.get("meeting_url") and payload_data.get("scheduled_at") and payload_data.get("ends_at"):
        mentor_label = payload_data.get("counsellor_name") or "Mentor"
        meet_url = create_meet_link(
            title=f"CareSkill: {payload_data.get('topic') or 'Counselling'} with {mentor_label}",
            starts_at=payload_data["scheduled_at"],
            ends_at=payload_data["ends_at"],
            description=f"CareSkill counselling session with {mentor_label}.",
        )
        if meet_url:
            payload_data["meeting_url"] = meet_url
            payload = payload.model_copy(update={"meeting_url": meet_url})

    session = wellness_crud.create_counselling_session(db, user_id, payload)
    reward_crud.award_rule_reward(
        db, user_id=user_id,
        trigger=RewardTrigger.counselling_booked,
        source_type="counselling", source_id=session.id,
        message="Counselling session booked",
    )
    return session


@router.patch("/counselling/{session_id}", response_model=CounsellingResponse,
              summary="Update a counselling session [mentor, admin]")
def update_session(
    user_id: int,
    session_id: int,
    payload: CounsellingUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role not in (
        UserRole.mentor, UserRole.admin, UserRole.super_admin
    ):
        raise HTTPException(status_code=403, detail="Only mentors and admins may update sessions")
    session = wellness_crud.update_counselling_session(db, session_id, payload)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if payload.status and payload.status.value == "completed":
        reward_crud.award_rule_reward(
            db, user_id=current_user.id,
            trigger=RewardTrigger.session_conducted,
            source_type="counselling", source_id=session_id,
            message="Counselling session conducted",
        )
    return session
