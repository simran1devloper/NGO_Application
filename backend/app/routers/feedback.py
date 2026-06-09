from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import admin_only, get_current_user
from ..models.feedback import Feedback, FeedbackStatus
from ..models.user import User
from ..schemas.feedback import FeedbackCreate, FeedbackReply, FeedbackResponse

router = APIRouter(prefix="/feedback", tags=["Feedback"])


@router.post("", status_code=201, response_model=FeedbackResponse,
             summary="Submit feedback (public)")
def submit_feedback(
    payload: FeedbackCreate,
    db: Session = Depends(get_db),
):
    feedback = Feedback(
        name=payload.name,
        email=payload.email,
        category=payload.category,
        rating=payload.rating,
        subject=payload.subject,
        message=payload.message,
        reference_id=payload.reference_id,
    )
    db.add(feedback)
    db.commit()
    db.refresh(feedback)
    return feedback


@router.post("/auth", status_code=201, response_model=FeedbackResponse,
             summary="Submit feedback as authenticated user")
def submit_feedback_auth(
    payload: FeedbackCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    feedback = Feedback(
        user_id=current_user.id,
        name=payload.name or current_user.name,
        email=payload.email or current_user.email,
        category=payload.category,
        rating=payload.rating,
        subject=payload.subject,
        message=payload.message,
        reference_id=payload.reference_id,
    )
    db.add(feedback)
    db.commit()
    db.refresh(feedback)
    return feedback


@router.get("", response_model=list[FeedbackResponse],
            summary="List all feedback [admin only]")
def list_feedback(
    category: Optional[str] = None,
    status: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    q = db.query(Feedback)
    if category:
        q = q.filter(Feedback.category == category)
    if status:
        q = q.filter(Feedback.status == status)
    return q.order_by(Feedback.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/stats", summary="Feedback statistics [admin only]")
def feedback_stats(
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    total    = db.query(Feedback).count()
    open_cnt = db.query(Feedback).filter(Feedback.status == FeedbackStatus.open).count()
    resolved = db.query(Feedback).filter(Feedback.status == FeedbackStatus.resolved).count()
    avg_rating_row = db.query(func.avg(Feedback.rating)).filter(
        Feedback.rating.isnot(None)
    ).scalar()
    return {
        "total":      total,
        "open":       open_cnt,
        "resolved":   resolved,
        "avg_rating": round(float(avg_rating_row or 0), 2),
    }


@router.get("/{feedback_id}", response_model=FeedbackResponse,
            summary="Get a single feedback [admin only]")
def get_feedback(
    feedback_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    fb = db.query(Feedback).filter(Feedback.id == feedback_id).first()
    if not fb:
        raise HTTPException(status_code=404, detail="Feedback not found")
    return fb


@router.patch("/{feedback_id}/reply", response_model=FeedbackResponse,
              summary="Admin reply to feedback [admin only]")
def reply_feedback(
    feedback_id: int,
    payload: FeedbackReply,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    fb = db.query(Feedback).filter(Feedback.id == feedback_id).first()
    if not fb:
        raise HTTPException(status_code=404, detail="Feedback not found")
    fb.admin_reply = payload.admin_reply
    fb.status = payload.status
    db.commit()
    db.refresh(fb)
    return fb


@router.delete("/{feedback_id}", status_code=204,
               summary="Delete feedback [admin only]")
def delete_feedback(
    feedback_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    fb = db.query(Feedback).filter(Feedback.id == feedback_id).first()
    if not fb:
        raise HTTPException(status_code=404, detail="Feedback not found")
    db.delete(fb)
    db.commit()
