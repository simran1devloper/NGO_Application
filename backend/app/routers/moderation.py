"""
Moderation router — mediator + admin only.

Comment moderation:
  POST  /moderation/comments/{id}/flag    – any logged-in user flags a comment
  POST  /moderation/comments/{id}/hide    – mediator/admin hides it
  POST  /moderation/comments/{id}/unhide  – mediator/admin restores it
  GET   /moderation/comments/flagged      – list flagged/hidden comments

Maker-checker content approval:
  GET   /moderation/content/pending               – pending_review posts + events
  POST  /moderation/content/post/{id}/approve     – approve creator post
  POST  /moderation/content/post/{id}/reject      – reject creator post
  POST  /moderation/content/event/{id}/approve    – approve event
  POST  /moderation/content/event/{id}/reject     – reject event
"""

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..crud import reward_crud
from ..database import get_db
from ..dependencies import admin_only, get_current_user, mediator_or_above
from ..models.comment import Comment
from ..models.creator_post import CreatorPost
from ..models.event import Event, EventStatus
from ..models.reward import RewardTrigger
from ..models.user import User, UserRole

router = APIRouter(prefix="/moderation", tags=["Moderation"])

_FLAG_THRESHOLD = 3   # auto-flag when this many reports accumulate


# ── Schemas ───────────────────────────────────────────────────────────────────

class HideBody(BaseModel):
    reason: Optional[str] = None


class RejectBody(BaseModel):
    reason: str


# ── Comment moderation ────────────────────────────────────────────────────────

@router.post("/comments/{comment_id}/flag", summary="Flag a comment (any logged-in user)")
def flag_comment(
    comment_id:   int,
    current_user: User = Depends(get_current_user),
    db:           Session = Depends(get_db),
):
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    if not comment:
        raise HTTPException(404, "Comment not found")
    if comment.is_deleted:
        raise HTTPException(400, "Cannot flag a deleted comment")
    if comment.user_id == current_user.id:
        raise HTTPException(400, "You cannot flag your own comment")

    comment.flag_count = (comment.flag_count or 0) + 1
    if comment.flag_count >= _FLAG_THRESHOLD:
        comment.is_flagged = True
    db.commit()
    return {"detail": "flagged", "flag_count": comment.flag_count, "is_flagged": comment.is_flagged}


@router.post("/comments/{comment_id}/hide", summary="Hide a flagged comment (mediator+)")
def hide_comment(
    comment_id: int,
    body:       HideBody = HideBody(),
    moderator:  User = Depends(mediator_or_above),
    db:         Session = Depends(get_db),
):
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    if not comment:
        raise HTTPException(404, "Comment not found")
    comment.is_hidden   = True
    comment.hidden_by   = moderator.id
    comment.hidden_reason = body.reason
    db.commit()
    return {"detail": "hidden", "comment_id": comment_id}


@router.post("/comments/{comment_id}/unhide", summary="Unhide a comment (mediator+)")
def unhide_comment(
    comment_id: int,
    moderator:  User = Depends(mediator_or_above),
    db:         Session = Depends(get_db),
):
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    if not comment:
        raise HTTPException(404, "Comment not found")
    comment.is_hidden   = False
    comment.hidden_by   = None
    comment.hidden_reason = None
    comment.is_flagged  = False
    db.commit()
    return {"detail": "unhidden", "comment_id": comment_id}


@router.get("/comments/flagged", summary="List flagged or hidden comments (mediator+)")
def list_flagged_comments(
    skip:  int = 0,
    limit: int = 50,
    _:  User = Depends(mediator_or_above),
    db: Session = Depends(get_db),
):
    comments = (
        db.query(Comment)
        .filter((Comment.is_flagged == True) | (Comment.is_hidden == True))  # noqa: E712
        .order_by(Comment.flag_count.desc(), Comment.created_at.desc())
        .offset(skip).limit(limit)
        .all()
    )
    return [
        {
            "id":            c.id,
            "post_id":       c.post_id,
            "user_id":       c.user_id,
            "author_name":   c.user.name if c.user else None,
            "body":          c.body,
            "flag_count":    c.flag_count,
            "is_flagged":    c.is_flagged,
            "is_hidden":     c.is_hidden,
            # "hidden_by" is intentionally omitted — mediator identity is private.
            # Use GET /moderation/audit/comments (admin only) for the full trail.
            "hidden_by_label": "Moderation Team" if c.hidden_by else None,
            "hidden_reason": c.hidden_reason,
            "is_deleted":    c.is_deleted,
            "created_at":    c.created_at.isoformat() if c.created_at else None,
        }
        for c in comments
    ]


# ── Content approval (maker-checker) ─────────────────────────────────────────

def _post_out(p: CreatorPost, *, admin_view: bool = False) -> dict:
    base = {
        "id":               p.id,
        "post_type":        p.post_type,
        "title":            p.title,
        "description":      p.description,
        "category":         p.category,
        "status":           p.status,
        "created_by":       p.created_by,
        "creator_name":     p.creator.name if p.creator else None,
        # Mediator identity hidden; only the fact and timestamp are exposed.
        "moderated":        p.approved_by is not None,
        "moderation_label": "Reviewed by the moderation team." if p.approved_by else None,
        "moderated_at":     p.approved_at.isoformat() if p.approved_at else None,
        "rejection_reason": p.rejection_reason,
        "created_at":       p.created_at.isoformat() if p.created_at else None,
    }
    if admin_view:
        base["approved_by_id"]   = p.approved_by
        base["approved_by_name"] = p.approver.name if p.approver else None
    return base


def _event_out(e: Event, *, admin_view: bool = False) -> dict:
    base = {
        "id":               e.id,
        "title":            e.title,
        "event_type":       e.event_type.value if e.event_type else None,
        "status":           e.status.value if e.status else None,
        "created_by":       e.created_by,
        "creator_name":     e.creator.name if e.creator else None,
        # Mediator identity hidden; only the fact and timestamp are exposed.
        "moderated":        e.approved_by is not None,
        "moderation_label": "Reviewed by the moderation team." if e.approved_by else None,
        "moderated_at":     e.approved_at.isoformat() if e.approved_at else None,
        "rejection_reason": e.rejection_reason,
        "created_at":       e.created_at.isoformat() if e.created_at else None,
    }
    if admin_view:
        base["approved_by_id"]   = e.approved_by
        base["approved_by_name"] = e.approver.name if e.approver else None
    return base


@router.get("/content/pending", summary="All pending_review content (mediator+)")
def pending_content(
    skip:  int = 0,
    limit: int = 50,
    _:  User = Depends(mediator_or_above),
    db: Session = Depends(get_db),
):
    posts = (
        db.query(CreatorPost)
        .filter(CreatorPost.status == "pending_review")
        .order_by(CreatorPost.updated_at.asc())
        .offset(skip).limit(limit)
        .all()
    )
    events = (
        db.query(Event)
        .filter(Event.status == EventStatus.pending_review)
        .order_by(Event.updated_at.asc())
        .offset(skip).limit(limit)
        .all()
    )
    return {
        "posts":  [_post_out(p) for p in posts],
        "events": [_event_out(e) for e in events],
    }


@router.post("/content/post/{post_id}/approve", summary="Approve creator post (mediator+)")
def approve_post(
    post_id:   int,
    moderator: User = Depends(mediator_or_above),
    db:        Session = Depends(get_db),
):
    post = db.query(CreatorPost).filter(CreatorPost.id == post_id).first()
    if not post:
        raise HTTPException(404, "Post not found")
    if post.status != "pending_review":
        raise HTTPException(400, f"Post status is '{post.status}', not pending_review")

    post.status      = "published"
    post.approved_by = moderator.id
    post.approved_at = datetime.now(timezone.utc)
    post.rejection_reason = None
    db.commit()
    db.refresh(post)

    reward_crud.award_rule_reward(
        db, user_id=post.created_by,
        trigger=RewardTrigger.post_approved,
        source_type="creator_post", source_id=post.id,
        message="Your post was approved by the moderation team",
    )

    return _post_out(post)


@router.post("/content/post/{post_id}/reject", summary="Reject creator post (mediator+)")
def reject_post(
    post_id:   int,
    body:      RejectBody,
    moderator: User = Depends(mediator_or_above),
    db:        Session = Depends(get_db),
):
    post = db.query(CreatorPost).filter(CreatorPost.id == post_id).first()
    if not post:
        raise HTTPException(404, "Post not found")
    if post.status not in ("pending_review", "published"):
        raise HTTPException(400, f"Cannot reject a post with status '{post.status}'")

    post.status           = "draft"
    post.rejection_reason = body.reason
    post.approved_by      = None
    post.approved_at      = None
    db.commit()
    db.refresh(post)
    return _post_out(post)


@router.post("/content/event/{event_id}/approve", summary="Approve event (mediator+)")
def approve_event(
    event_id:  int,
    moderator: User = Depends(mediator_or_above),
    db:        Session = Depends(get_db),
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(404, "Event not found")
    if event.status != EventStatus.pending_review:
        raise HTTPException(400, f"Event status is '{event.status.value}', not pending_review")

    event.status      = EventStatus.published
    event.approved_by = moderator.id
    event.approved_at = datetime.now(timezone.utc)
    event.rejection_reason = None
    db.commit()
    db.refresh(event)

    reward_crud.award_rule_reward(
        db, user_id=event.created_by,
        trigger=RewardTrigger.event_published,
        source_type="event", source_id=event.id,
        message="Your event was approved and published",
    )

    return _event_out(event)


@router.post("/content/event/{event_id}/reject", summary="Reject event (mediator+)")
def reject_event(
    event_id:  int,
    body:      RejectBody,
    moderator: User = Depends(mediator_or_above),
    db:        Session = Depends(get_db),
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(404, "Event not found")
    if event.status not in (EventStatus.pending_review, EventStatus.published):
        raise HTTPException(400, f"Cannot reject event with status '{event.status.value}'")

    event.status           = EventStatus.draft
    event.rejection_reason = body.reason
    event.approved_by      = None
    event.approved_at      = None
    db.commit()
    db.refresh(event)
    return _event_out(event)


# ── Admin audit (full trail with mediator identity) ───────────────────────────

@router.get("/audit/comments", summary="Full comment moderation audit (admin only)")
def audit_comments(
    skip:  int = 0,
    limit: int = 100,
    _:  User = Depends(admin_only),
    db: Session = Depends(get_db),
):
    """Returns every hidden/flagged comment with the actual moderator's identity."""
    comments = (
        db.query(Comment)
        .filter((Comment.is_flagged == True) | (Comment.is_hidden == True))  # noqa: E712
        .order_by(Comment.created_at.desc())
        .offset(skip).limit(limit)
        .all()
    )
    hiders = {
        c.hidden_by: db.query(User).filter(User.id == c.hidden_by).first()
        for c in comments if c.hidden_by
    }
    return [
        {
            "id":              c.id,
            "post_id":         c.post_id,
            "user_id":         c.user_id,
            "author_name":     c.user.name if c.user else None,
            "body":            c.body,
            "flag_count":      c.flag_count,
            "is_flagged":      c.is_flagged,
            "is_hidden":       c.is_hidden,
            "hidden_by_id":    c.hidden_by,
            "hidden_by_name":  hiders[c.hidden_by].name if c.hidden_by and hiders.get(c.hidden_by) else None,
            "hidden_reason":   c.hidden_reason,
            "created_at":      c.created_at.isoformat() if c.created_at else None,
        }
        for c in comments
    ]


@router.get("/audit/content", summary="Full content approval audit (admin only)")
def audit_content(
    skip:  int = 0,
    limit: int = 100,
    _:  User = Depends(admin_only),
    db: Session = Depends(get_db),
):
    """Returns all moderated posts and events with the actual moderator's identity."""
    posts = (
        db.query(CreatorPost)
        .filter(CreatorPost.approved_by.isnot(None))
        .order_by(CreatorPost.approved_at.desc())
        .offset(skip).limit(limit)
        .all()
    )
    events = (
        db.query(Event)
        .filter(Event.approved_by.isnot(None))
        .order_by(Event.approved_at.desc())
        .offset(skip).limit(limit)
        .all()
    )
    return {
        "posts":  [_post_out(p, admin_view=True) for p in posts],
        "events": [_event_out(e, admin_view=True) for e in events],
    }
