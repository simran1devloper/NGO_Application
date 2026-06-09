from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from ..crud import event_crud, reward_crud
from ..database import get_db
from ..dependencies import get_current_user, require_role
from ..models.event import EventStatus
from ..models.reward import RewardTrigger
from ..models.user import User, UserRole
from ..schemas.event import (
    AttachQuizRequest,
    BookSlotRequest,
    EventCreate,
    EventParticipantResponse,
    EventResponse,
    EventSelectionResponse,
    EventSlotCreate,
    EventSlotResponse,
    EventUpdate,
    RunSelectionRequest,
    LinkEventQuizRequest,
)

router = APIRouter(prefix="/events", tags=["Events"])


# ── helpers ────────────────────────────────────────────────────────────────────

def _event_or_404(db: Session, event_id: int):
    event = event_crud.get_event(db, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return event


def _can_manage_events(user: User) -> bool:
    return user.role in (
        UserRole.admin,
        UserRole.super_admin,
        UserRole.content_creator,
        UserRole.mentor,
    )


def _is_public_event(event, db: Session) -> bool:
    if event.status not in (
        EventStatus.published,
        EventStatus.registration_open,
        EventStatus.live,
    ):
        return False
    if event.event_type.value not in ("quiz", "daily_challenge") and not event.is_daily_challenge:
        return True
    if not event.quiz_id:
        return False
    from ..models.quiz import Quiz

    quiz = db.query(Quiz).filter(Quiz.id == event.quiz_id).first()
    return bool(quiz and quiz.is_active)


# ── create event ───────────────────────────────────────────────────────────────

@router.post("/", response_model=EventResponse, status_code=201,
             summary="Create a new event [admin, super_admin, mentor, content_creator]")
def create_event(
    data: EventCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role(UserRole.admin, UserRole.super_admin, UserRole.mentor, UserRole.content_creator)
    ),
):
    event = event_crud.create_event(db, data, creator_id=current_user.id)
    return event


@router.post("/create", response_model=EventResponse, status_code=201,
             summary="Create a new event [admin, super_admin, mentor, content_creator]")
def create_event_alias(
    data: EventCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role(UserRole.admin, UserRole.super_admin, UserRole.mentor, UserRole.content_creator)
    ),
):
    event = event_crud.create_event(db, data, creator_id=current_user.id)
    return event


# ── list events ────────────────────────────────────────────────────────────────

@router.get("/", response_model=list[EventResponse],
            summary="List events [any authenticated]")
def list_events(
    status: str | None = Query(default=None),
    event_type: str | None = Query(default=None),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=50, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return event_crud.get_events(
        db,
        status=status,
        event_type=event_type,
        skip=skip,
        limit=limit,
        public_only=not _can_manage_events(current_user),
    )


# ── get event detail ───────────────────────────────────────────────────────────

@router.get("/{event_id}", response_model=EventResponse,
            summary="Get event detail [any authenticated]")
def get_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    event = _event_or_404(db, event_id)
    if not _can_manage_events(current_user) and not _is_public_event(event, db):
        raise HTTPException(status_code=404, detail="Event not found")
    return event


# ── update event ───────────────────────────────────────────────────────────────

@router.patch("/{event_id}", response_model=EventResponse,
              summary="Update event [admin, super_admin, mentor, content_creator]")
def update_event(
    event_id: int,
    data: EventUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(
        require_role(UserRole.admin, UserRole.super_admin, UserRole.mentor, UserRole.content_creator)
    ),
):
    event = event_crud.update_event(db, event_id, data)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return event


# ── delete event ───────────────────────────────────────────────────────────────

@router.delete("/{event_id}", status_code=204,
               summary="Delete event [admin, super_admin]")
def delete_event(
    event_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
):
    deleted = event_crud.delete_event(db, event_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Event not found")


# ── publish event ──────────────────────────────────────────────────────────────

@router.post("/{event_id}/publish", response_model=EventResponse,
             summary="Publish event [admin, super_admin, mentor, content_creator]")
def publish_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role(UserRole.admin, UserRole.super_admin, UserRole.mentor, UserRole.content_creator)
    ),
):
    event = event_crud.publish_event(db, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    reward_crud.award_rule_reward(
        db, user_id=current_user.id,
        trigger=RewardTrigger.event_published,
        source_type="event", source_id=event.id,
        message=f"Event '{event.title}' published",
    )
    return event


# ── advance status ─────────────────────────────────────────────────────────────

@router.post("/{event_id}/status", response_model=EventResponse,
             summary="Advance event status [admin, super_admin]")
def advance_status(
    event_id: int,
    body: dict,
    db: Session = Depends(get_db),
    _: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
):
    new_status_str = body.get("new_status")
    if not new_status_str:
        raise HTTPException(status_code=422, detail="new_status is required")
    try:
        new_status = EventStatus(new_status_str)
    except ValueError:
        raise HTTPException(status_code=422, detail=f"Invalid status: {new_status_str}")
    event = event_crud.advance_status(db, event_id, new_status)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return event


# ── quizzes ────────────────────────────────────────────────────────────────────

@router.post("/{event_id}/quizzes", status_code=201,
             summary="Attach quiz to event [admin, super_admin, mentor, content_creator]")
def attach_quiz(
    event_id: int,
    data: AttachQuizRequest,
    db: Session = Depends(get_db),
    _: User = Depends(
        require_role(UserRole.admin, UserRole.super_admin, UserRole.mentor, UserRole.content_creator)
    ),
):
    _event_or_404(db, event_id)
    quiz = event_crud.attach_quiz(db, event_id, data)
    return {"id": quiz.id, "quiz_title": quiz.quiz_title, "quiz_id": quiz.quiz_id, "is_primary": quiz.is_primary}


@router.get("/{event_id}/quizzes",
            summary="List quizzes for event [any authenticated]")
def list_quizzes(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    event = _event_or_404(db, event_id)
    if not _can_manage_events(current_user) and not _is_public_event(event, db):
        raise HTTPException(status_code=404, detail="Event not found")
    from ..models.quiz import Quiz

    active_quiz_ids = {
        quiz.id
        for quiz in db.query(Quiz)
        .filter(Quiz.id.in_([q.quiz_id for q in event.quizzes if q.quiz_id]))
        .filter(Quiz.is_active.is_(True))
        .all()
    }
    return [
        {"id": q.id, "quiz_title": q.quiz_title, "quiz_id": q.quiz_id, "is_primary": q.is_primary}
        for q in event.quizzes
        if _can_manage_events(current_user) or q.quiz_id in active_quiz_ids
    ]


# ── slots ──────────────────────────────────────────────────────────────────────

@router.post("/{event_id}/slots", response_model=EventSlotResponse, status_code=201,
             summary="Create an event slot [admin, super_admin, mentor]")
def create_event_slot(
    event_id: int,
    data: EventSlotCreate,
    db: Session = Depends(get_db),
    _: User = Depends(
        require_role(UserRole.admin, UserRole.super_admin, UserRole.mentor)
    ),
):
    _event_or_404(db, event_id)
    return event_crud.create_slot(db, event_id, data)


@router.get("/{event_id}/slots", response_model=list[EventSlotResponse],
            summary="List event slots [any authenticated]")
def list_event_slots(
    event_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    _event_or_404(db, event_id)
    return event_crud.get_slots(db, event_id)


# ── register ───────────────────────────────────────────────────────────────────

@router.post("/{event_id}/register", response_model=EventParticipantResponse, status_code=201,
             summary="Register for event [any authenticated student]")
def register_for_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    event = _event_or_404(db, event_id)
    if event.status not in (EventStatus.published, EventStatus.registration_open):
        raise HTTPException(
            status_code=400,
            detail="Event is not open for registration",
        )
    if not _is_public_event(event, db):
        raise HTTPException(
            status_code=400,
            detail="Event quiz is not published",
        )
    participant = event_crud.register_participant(db, event_id, current_user.id)
    reward_crud.award_rule_reward(
        db, user_id=current_user.id,
        trigger=RewardTrigger.event_attended,
        source_type="event", source_id=event_id,
        message=f"Registered for event",
    )
    return participant


@router.post("/{event_id}/book-slot", response_model=EventParticipantResponse, status_code=201,
             summary="Book an event slot [workshop, counselling, campaign, competition]")
def book_event_slot(
    event_id: int,
    data: BookSlotRequest = BookSlotRequest(),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    event = _event_or_404(db, event_id)
    if event.status not in (EventStatus.published, EventStatus.registration_open, EventStatus.live):
        raise HTTPException(status_code=400, detail="Event is not open for booking")
    participant = event_crud.book_event_slot(db, event_id, current_user.id, data.slot_id)
    if not participant:
        raise HTTPException(status_code=400, detail="No available slot")
    return participant


@router.get("/{event_id}/my-registration", response_model=Optional[EventParticipantResponse],
            summary="Get current user's registration for this event [any authenticated user]")
def get_my_registration(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from ..models.event import EventParticipant
    participant = (
        db.query(EventParticipant)
        .filter(EventParticipant.event_id == event_id, EventParticipant.user_id == current_user.id)
        .first()
    )
    return participant


# ── participants ───────────────────────────────────────────────────────────────

@router.get("/{event_id}/participants", response_model=list[EventParticipantResponse],
            summary="List participants [admin, super_admin, mentor]")
def list_participants(
    event_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(
        require_role(UserRole.admin, UserRole.super_admin, UserRole.mentor)
    ),
):
    _event_or_404(db, event_id)
    return event_crud.get_participants(db, event_id)


# ── selection ──────────────────────────────────────────────────────────────────

@router.post("/{event_id}/select", response_model=list[EventSelectionResponse],
             summary="Run selection [admin, super_admin]")
def run_selection(
    event_id: int,
    request: RunSelectionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
):
    _event_or_404(db, event_id)
    selections = event_crud.run_selection(db, event_id, current_user.id, request)
    return selections


@router.get("/{event_id}/selections", response_model=list[EventSelectionResponse],
            summary="Get selections [admin, super_admin]")
def get_selections(
    event_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
):
    event = _event_or_404(db, event_id)
    return event.selections


# ── counselling ────────────────────────────────────────────────────────────────

@router.post("/{event_id}/counselling",
             summary="Assign counselling sessions to selected participants [admin, super_admin]")
def assign_counselling(
    event_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
):
    _event_or_404(db, event_id)
    count = event_crud.assign_counselling(db, event_id)
    return {"assigned_count": count}


# ── prefix-less events & quiz pipeline endpoints ───────────────────────────────

root_router = APIRouter(tags=["Quiz Event Pipeline"])


@root_router.get("/daily-challenge/today", summary="Today's daily challenge from event pipeline")
def get_today_daily_challenge(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from ..models.event import Event, EventStatus
    from ..crud import quiz_crud
    from datetime import datetime, time, timezone
    
    today = datetime.now().date()
    # Query published/live events that are daily challenges
    event = (
        db.query(Event)
        .filter(
            Event.is_daily_challenge == True,
            Event.status.in_([EventStatus.published, EventStatus.registration_open, EventStatus.live]),
        )
        .order_by(Event.id.desc())
        .all()
    )
    event = next(
        (
            candidate for candidate in event
            if (candidate.start_date or candidate.event_start) is None
            or (candidate.start_date or candidate.event_start).date() <= today
            if _can_manage_events(current_user) or _is_public_event(candidate, db)
        ),
        None,
    )
    if not event:
        raise HTTPException(status_code=404, detail="No active daily challenge found")
        
    # Get linked quiz difficulty, reward, and live participation.
    from ..models.quiz import Quiz, QuizAttempt
    quiz = db.query(Quiz).filter(Quiz.id == event.quiz_id).first() if event.quiz_id else None
    if not _can_manage_events(current_user) and (not quiz or not quiz.is_active):
        raise HTTPException(status_code=404, detail="No active daily challenge found")
    
    difficulty = quiz.difficulty.value if quiz else "medium"
    xp_reward = quiz.xp_reward if quiz else 100
    
    # Calculate time remaining
    now = datetime.now(timezone.utc)
    end_dt = event.end_date or event.event_end
    if end_dt:
        if end_dt.tzinfo is None:
            now_naive = datetime.now()
            time_remaining = max(0, int((end_dt - now_naive).total_seconds()))
        else:
            time_remaining = max(0, int((end_dt - now).total_seconds()))
    else:
        # Fallback to end of today
        end_of_day = datetime.combine(now.date(), time(23, 59, 59))
        time_remaining = max(0, int((end_of_day - now.replace(tzinfo=None)).total_seconds()))
        
    completed = False
    participants_count = event.participant_count
    if event.quiz_id:
        completed = quiz_crud.has_completed_quiz(db, current_user.id, event.quiz_id)
        attempt_count = (
            db.query(QuizAttempt.user_id)
            .filter(QuizAttempt.quiz_id == event.quiz_id)
            .distinct()
            .count()
        )
        participants_count = max(participants_count, attempt_count)
        
    return {
        "id": event.id,
        "challenge_date": ((event.start_date or event.event_start).date().isoformat()
                           if (event.start_date or event.event_start) else today.isoformat()),
        "title": event.title,
        "difficulty": difficulty,
        "xp_reward": xp_reward,
        "participants_count": participants_count,
        "time_remaining_seconds": time_remaining,
        "quiz_id": event.quiz_id,
        "completed": completed
    }


@root_router.post("/quiz-manager/link-event", summary="Link quiz to event [admin, content_creator]")
def link_quiz_to_event(
    data: LinkEventQuizRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_role(UserRole.admin, UserRole.super_admin, UserRole.content_creator)),
):
    from ..models.quiz import Quiz
    from ..models.event import Event
    
    event = db.query(Event).filter(Event.id == data.event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
        
    quiz = db.query(Quiz).filter(Quiz.id == data.quiz_id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
        
    event.quiz_id = data.quiz_id
    db.commit()
    db.refresh(event)
    
    # Sync mapping and daily challenge if needed
    event_crud.sync_quiz_mapping(db, event)
    if event.status in (EventStatus.published, EventStatus.registration_open, EventStatus.live):
        event_crud.sync_daily_challenge(db, event)
        
    return {"status": "ok", "event_id": event.id, "quiz_id": event.quiz_id}
