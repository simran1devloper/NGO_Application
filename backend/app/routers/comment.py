from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import admin_only, get_current_user
from ..models.comment import Comment
from ..models.creator_post import CreatorPost
from ..models.user import User
from ..schemas.comment import (
    CommentCreate,
    CommentResponse,
    CommentUpdate,
    CommentWithRepliesResponse,
)

router = APIRouter(prefix="/comments", tags=["Comments"])


def _serialize(c: Comment, db: Session) -> CommentResponse:
    reply_count = db.query(func.count(Comment.id)).filter(
        Comment.parent_id == c.id,
        Comment.is_deleted.is_(False),
    ).scalar() or 0

    is_hidden  = bool(c.is_hidden)
    is_deleted = bool(c.is_deleted)

    # Body: deleted > hidden > normal.  Mediator identity never exposed here.
    if is_deleted:
        body = "[deleted]"
    elif is_hidden:
        body = "[This comment was removed by the moderation team.]"
    else:
        body = c.body

    return CommentResponse(
        id=c.id,
        post_id=c.post_id,
        user_id=c.user_id,
        parent_id=c.parent_id,
        body=body,
        is_edited=c.is_edited,
        is_deleted=is_deleted,
        is_hidden=is_hidden,
        moderation_label=(
            "This comment was removed by the moderation team."
            if is_hidden and not is_deleted else None
        ),
        created_at=c.created_at,
        updated_at=c.updated_at,
        # Author is shown even on hidden comments (transparency about who posted),
        # but not on deleted ones (author chose to remove).
        user={"id": c.user.id, "name": c.user.name} if c.user and not is_deleted else None,
        reply_count=reply_count,
    )


@router.post("", status_code=201, response_model=CommentResponse,
             summary="Post a comment on a creator post")
def create_comment(
    payload: CommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = db.query(CreatorPost).filter(CreatorPost.id == payload.post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    if payload.parent_id:
        parent = db.query(Comment).filter(Comment.id == payload.parent_id).first()
        if not parent or parent.post_id != payload.post_id:
            raise HTTPException(status_code=400, detail="Invalid parent comment")
        if parent.parent_id is not None:
            raise HTTPException(status_code=400, detail="Only one level of replies is supported")

    comment = Comment(
        post_id=payload.post_id,
        user_id=current_user.id,
        parent_id=payload.parent_id,
        body=payload.body.strip(),
    )
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return _serialize(comment, db)


@router.get("/post/{post_id}", response_model=list[CommentWithRepliesResponse],
            summary="Get top-level comments for a post (with replies)")
def list_comments(
    post_id: int,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    top_level = (
        db.query(Comment)
        .filter(Comment.post_id == post_id, Comment.parent_id.is_(None))
        .order_by(Comment.created_at.asc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    result = []
    for c in top_level:
        base = _serialize(c, db)
        replies_raw = (
            db.query(Comment)
            .filter(
                Comment.parent_id == c.id,
                Comment.is_deleted.is_(False),
            )
            .order_by(Comment.created_at.asc())
            .all()
        )
        replies = [_serialize(r, db) for r in replies_raw]
        result.append(CommentWithRepliesResponse(**base.model_dump(), replies=replies))

    return result


@router.get("/post/{post_id}/count", summary="Get comment count for a post")
def comment_count(
    post_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    count = db.query(func.count(Comment.id)).filter(
        Comment.post_id == post_id,
        Comment.is_deleted.is_(False),
    ).scalar() or 0
    return {"post_id": post_id, "count": count}


@router.patch("/{comment_id}", response_model=CommentResponse,
              summary="Edit your own comment")
def update_comment(
    comment_id: int,
    payload: CommentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    if not comment:
        raise HTTPException(status_code=404, detail="Comment not found")
    if comment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only edit your own comments")
    if comment.is_deleted:
        raise HTTPException(status_code=400, detail="Cannot edit a deleted comment")

    comment.body = payload.body.strip()
    comment.is_edited = True
    db.commit()
    db.refresh(comment)
    return _serialize(comment, db)


@router.delete("/{comment_id}", status_code=200,
               summary="Soft-delete a comment (author or admin)")
def delete_comment(
    comment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    if not comment:
        raise HTTPException(status_code=404, detail="Comment not found")

    from ..models.user import UserRole
    is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
    if comment.user_id != current_user.id and not is_admin:
        raise HTTPException(status_code=403, detail="Not allowed")

    comment.is_deleted = True
    db.commit()
    return {"ok": True, "comment_id": comment_id}


@router.delete("/{comment_id}/hard", status_code=204,
               summary="Permanently delete a comment [admin only]")
def hard_delete_comment(
    comment_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    if not comment:
        raise HTTPException(status_code=404, detail="Comment not found")
    db.delete(comment)
    db.commit()
