"""
Review system — users rate courses/mentors/posts/events (1–5 stars + text).
New reviews are pending until a mediator approves them.

Public:
  GET  /reviews/{target_type}/{target_id}         – list approved reviews
  GET  /reviews/{target_type}/{target_id}/summary – average rating + count

Authenticated (student+):
  POST   /reviews                   – create review (one per target)
  GET    /reviews/my                – my reviews
  PATCH  /reviews/{id}              – edit own review (resets to pending)
  DELETE /reviews/{id}              – delete own review

Mediator+ (approve / reject):
  GET    /reviews/pending           – list all pending reviews
  PATCH  /reviews/{id}/approve      – approve
  PATCH  /reviews/{id}/reject       – reject with reason
  DELETE /reviews/{id}/hard         – permanent delete (admin only)
"""

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import admin_only, get_current_user, mediator_or_above
from ..models.review import Review, ReviewStatus, ReviewTargetType
from ..models.user import User

router = APIRouter(prefix="/reviews", tags=["Reviews"])


# ── Schemas ───────────────────────────────────────────────────────────────────

class ReviewCreate(BaseModel):
    target_type: ReviewTargetType
    target_id:   int
    rating:      int = Field(..., ge=1, le=5)
    title:       Optional[str] = None
    body:        str = Field(..., min_length=10)


class ReviewUpdate(BaseModel):
    rating: Optional[int] = Field(None, ge=1, le=5)
    title:  Optional[str] = None
    body:   Optional[str] = Field(None, min_length=10)


class RejectBody(BaseModel):
    reason: str


def _review_out(r: Review, *, admin_view: bool = False) -> dict:
    """
    Serialize a Review.

    admin_view=False (default, used for all public + mediator endpoints):
      - `reviewed_by` is NEVER exposed — mediator identity is hidden
      - `moderated` boolean tells the frontend that moderation happened
      - `moderation_label` gives a human-readable note

    admin_view=True (admin-only audit endpoint only):
      - Full data including reviewed_by ID and name
    """
    moderated = r.reviewed_by is not None

    if admin_view:
        moderator_field: dict = {
            "reviewed_by_id":   r.reviewed_by,
            "reviewed_by_name": r.moderator.name if r.moderator else None,
            "reviewed_at":      r.reviewed_at.isoformat() if r.reviewed_at else None,
        }
    else:
        moderator_field = {
            "moderated":       moderated,
            "moderation_label": (
                "Reviewed by the moderation team."
                if moderated else None
            ),
            "reviewed_at": r.reviewed_at.isoformat() if r.reviewed_at else None,
        }

    return {
        "id":               r.id,
        "user_id":          r.user_id,
        "author_name":      r.author.name if r.author else None,
        "target_type":      r.target_type,
        "target_id":        r.target_id,
        "rating":           r.rating,
        "title":            r.title,
        "body":             r.body,
        "status":           r.status,
        "rejection_reason": r.rejection_reason,
        "is_edited":        r.is_edited,
        "created_at":       r.created_at.isoformat() if r.created_at else None,
        "updated_at":       r.updated_at.isoformat() if r.updated_at else None,
        **moderator_field,
    }


# ── Public ────────────────────────────────────────────────────────────────────

@router.get("/{target_type}/{target_id}/summary")
def review_summary(target_type: ReviewTargetType, target_id: int, db: Session = Depends(get_db)):
    q = db.query(Review).filter(
        Review.target_type == target_type.value,
        Review.target_id   == target_id,
        Review.status      == ReviewStatus.approved.value,
    )
    count = q.count()
    avg   = db.query(func.avg(Review.rating)).filter(
        Review.target_type == target_type.value,
        Review.target_id   == target_id,
        Review.status      == ReviewStatus.approved.value,
    ).scalar()
    return {"count": count, "average_rating": round(avg, 2) if avg else None}


@router.get("/{target_type}/{target_id}")
def list_reviews(
    target_type: ReviewTargetType,
    target_id:   int,
    skip:  int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
):
    reviews = (
        db.query(Review)
        .filter(
            Review.target_type == target_type.value,
            Review.target_id   == target_id,
            Review.status      == ReviewStatus.approved.value,
        )
        .order_by(Review.created_at.desc())
        .offset(skip).limit(limit)
        .all()
    )
    return [_review_out(r) for r in reviews]


# ── Authenticated ─────────────────────────────────────────────────────────────

@router.get("/my", summary="My reviews")
def my_reviews(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    reviews = (
        db.query(Review)
        .filter(Review.user_id == current_user.id)
        .order_by(Review.created_at.desc())
        .all()
    )
    return [_review_out(r) for r in reviews]


@router.post("", status_code=201)
def create_review(
    body:         ReviewCreate,
    current_user: User = Depends(get_current_user),
    db:           Session = Depends(get_db),
):
    existing = db.query(Review).filter(
        Review.user_id     == current_user.id,
        Review.target_type == body.target_type.value,
        Review.target_id   == body.target_id,
    ).first()
    if existing:
        raise HTTPException(400, "You have already reviewed this item. Edit your existing review.")

    review = Review(
        user_id     = current_user.id,
        target_type = body.target_type.value,
        target_id   = body.target_id,
        rating      = body.rating,
        title       = body.title,
        body        = body.body,
        status      = ReviewStatus.pending.value,
    )
    db.add(review)
    db.commit()
    db.refresh(review)
    return _review_out(review)


@router.patch("/{review_id}")
def edit_review(
    review_id:    int,
    body:         ReviewUpdate,
    current_user: User = Depends(get_current_user),
    db:           Session = Depends(get_db),
):
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review:
        raise HTTPException(404, "Review not found")
    if review.user_id != current_user.id:
        raise HTTPException(403, "You can only edit your own reviews")

    if body.rating is not None:
        review.rating = body.rating
    if body.title is not None:
        review.title = body.title
    if body.body is not None:
        review.body = body.body

    review.is_edited        = True
    review.status           = ReviewStatus.pending.value   # re-enter approval queue
    review.rejection_reason = None
    db.commit()
    db.refresh(review)
    return _review_out(review)


@router.delete("/{review_id}", status_code=200)
def delete_review(
    review_id:    int,
    current_user: User = Depends(get_current_user),
    db:           Session = Depends(get_db),
):
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review:
        raise HTTPException(404, "Review not found")
    from ..models.user import UserRole
    is_mod = current_user.role in (UserRole.mediator, UserRole.admin, UserRole.super_admin)
    if review.user_id != current_user.id and not is_mod:
        raise HTTPException(403, "Access denied")
    db.delete(review)
    db.commit()
    return {"detail": "deleted"}


# ── Mediator ──────────────────────────────────────────────────────────────────

@router.get("/pending", summary="Pending reviews (mediator+)")
def pending_reviews(
    skip:  int = 0,
    limit: int = 50,
    _:  User = Depends(mediator_or_above),
    db: Session = Depends(get_db),
):
    reviews = (
        db.query(Review)
        .filter(Review.status == ReviewStatus.pending.value)
        .order_by(Review.created_at.asc())
        .offset(skip).limit(limit)
        .all()
    )
    return [_review_out(r) for r in reviews]


@router.patch("/{review_id}/approve", summary="Approve review (mediator+)")
def approve_review(
    review_id: int,
    moderator: User = Depends(mediator_or_above),
    db:        Session = Depends(get_db),
):
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review:
        raise HTTPException(404, "Review not found")
    if review.status == ReviewStatus.approved.value:
        raise HTTPException(400, "Already approved")

    review.status      = ReviewStatus.approved.value
    review.reviewed_by = moderator.id
    review.reviewed_at = datetime.now(timezone.utc)
    review.rejection_reason = None
    db.commit()
    db.refresh(review)
    return _review_out(review)


@router.patch("/{review_id}/reject", summary="Reject review (mediator+)")
def reject_review(
    review_id: int,
    body:      RejectBody,
    moderator: User = Depends(mediator_or_above),
    db:        Session = Depends(get_db),
):
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review:
        raise HTTPException(404, "Review not found")

    review.status           = ReviewStatus.rejected.value
    review.reviewed_by      = moderator.id
    review.reviewed_at      = datetime.now(timezone.utc)
    review.rejection_reason = body.reason
    db.commit()
    db.refresh(review)
    return _review_out(review)


@router.delete("/{review_id}/hard", status_code=204, summary="Hard delete (admin only)")
def hard_delete_review(
    review_id: int,
    _:  User = Depends(admin_only),
    db: Session = Depends(get_db),
):
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review:
        raise HTTPException(404, "Review not found")
    db.delete(review)
    db.commit()


# ── Admin audit ───────────────────────────────────────────────────────────────

@router.get("/audit", summary="Full moderation audit for reviews (admin only)")
def review_audit(
    skip:   int = 0,
    limit:  int = 100,
    status: Optional[str] = None,
    _:  User = Depends(admin_only),
    db: Session = Depends(get_db),
):
    """
    Returns reviews with full moderator identity (reviewed_by_id + name).
    Restricted to admins only — mediators see only the anonymised view.
    """
    q = db.query(Review)
    if status:
        q = q.filter(Review.status == status)
    reviews = q.order_by(Review.created_at.desc()).offset(skip).limit(limit).all()
    return [_review_out(r, admin_view=True) for r in reviews]
