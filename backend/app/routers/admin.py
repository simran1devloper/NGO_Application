from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import admin_only
from ..models.notification import AdminNotification
from ..models.user import User, UserRole
from ..permissions import highest_role, serialize_roles
from ..schemas.user import UserResponse

router = APIRouter(prefix="/admin", tags=["Admin"])


# ── request bodies ────────────────────────────────────────────────────────────

class AssignRoleBody(BaseModel):
    role: str
    access_status: str = "approved"
    verification_note: Optional[str] = None


class RejectBody(BaseModel):
    reason: Optional[str] = None


class BlockBody(BaseModel):
    reason: Optional[str] = None


class BulkApproveBody(BaseModel):
    user_ids: List[int]
    role: str
    access_status: str = "approved"
    verification_note: Optional[str] = None


class BulkDeleteBody(BaseModel):
    user_ids: List[int]


class MultiRoleBody(BaseModel):
    roles: List[str]   # e.g. ["mentor", "content_creator"]
    access_status: str = "approved"
    verification_note: Optional[str] = None


# ── helpers ───────────────────────────────────────────────────────────────────

def _get_or_404(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


def _parse_role_strings(role_values: List[str]) -> list[UserRole]:
    if not role_values:
        raise HTTPException(status_code=422, detail="roles list must not be empty")
    roles: list[UserRole] = []
    for value in role_values:
        try:
            role = UserRole(value)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=f"Invalid role: {value}") from exc
        if role not in roles:
            roles.append(role)
    return roles


def _assert_can_assign_roles(current_user: User, roles: list[UserRole]) -> None:
    if UserRole.super_admin in roles and current_user.role != UserRole.super_admin:
        raise HTTPException(status_code=403, detail="Only super_admin can assign super_admin role")


def _apply_roles(user: User, roles: list[UserRole]) -> None:
    primary = highest_role(roles)
    user.role = primary
    user.roles = serialize_roles(roles)


# ── stats ─────────────────────────────────────────────────────────────────────

@router.get("/stats", summary="Admin dashboard statistics [admin only]")
def get_stats(
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    total    = db.query(User).count()
    active   = db.query(User).filter(User.access_status == "approved").count()
    pending  = db.query(User).filter(User.access_status == "pending_verification").count()
    blocked  = db.query(User).filter(User.access_status == "deactivated").count()
    rejected = db.query(User).filter(User.access_status == "rejected").count()

    role_counts: dict[str, int] = {}
    for role in UserRole:
        role_counts[role.value] = (
            db.query(User)
            .filter((User.role == role) | (User.roles.contains(f'"{role.value}"')))
            .count()
        )

    return {
        "total_users":    total,
        "active_users":   active,
        "pending_users":  pending,
        "blocked_users":  blocked,
        "rejected_users": rejected,
        "role_counts":    role_counts,
    }


# ── user list ─────────────────────────────────────────────────────────────────

@router.get("/users", response_model=list[UserResponse],
            summary="List all users with optional filters [admin only]")
def list_users(
    search: Optional[str] = None,
    role: Optional[str] = None,
    status: Optional[str] = None,
    skip: int = 0,
    limit: int = 200,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    q = db.query(User)
    if search:
        like = f"%{search}%"
        q = q.filter(
            (User.name.ilike(like)) | (User.email.ilike(like))
        )
    if role:
        try:
            role_obj = UserRole(role)
            q = q.filter(
                (User.role == role_obj) | (User.roles.contains(f'"{role_obj.value}"'))
            )
        except ValueError:
            pass
    if status:
        q = q.filter(User.access_status == status)
    return q.order_by(User.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/users/pending", response_model=list[UserResponse],
            summary="List users awaiting approval [admin only]")
def list_pending_users(
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    return (
        db.query(User)
        .filter(User.access_status == "pending_verification")
        .order_by(User.created_at.desc())
        .all()
    )


@router.get("/users/{user_id}", response_model=UserResponse,
            summary="Get full user detail [admin only]")
def get_user(
    user_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    return _get_or_404(db, user_id)


# ── approval actions ──────────────────────────────────────────────────────────

@router.patch("/users/{user_id}/assign-role", response_model=UserResponse,
              summary="Approve user and assign role [admin only]")
def assign_role(
    user_id: int,
    payload: AssignRoleBody,
    db: Session = Depends(get_db),
    current_user: User = Depends(admin_only),
):
    roles = _parse_role_strings([payload.role])
    _assert_can_assign_roles(current_user, roles)
    new_role = roles[0]

    user = _get_or_404(db, user_id)
    _apply_roles(user, roles)
    user.access_status = payload.access_status
    if payload.verification_note:
        user.verification_note = payload.verification_note

    _notify(db, user_id=user_id,
            title="Account Approved",
            message=f"{user.name} has been approved as {new_role.value}.",
            ntype="approval")
    db.commit()
    db.refresh(user)
    return user


@router.patch("/users/{user_id}/set-roles", response_model=UserResponse,
              summary="Set all roles for a user — primary role auto-computed as highest [admin only]")
def set_user_roles(
    user_id: int,
    payload: MultiRoleBody,
    db: Session = Depends(get_db),
    current_user: User = Depends(admin_only),
):
    role_objs = _parse_role_strings(payload.roles)
    _assert_can_assign_roles(current_user, role_objs)

    user = _get_or_404(db, user_id)
    _apply_roles(user, role_objs)
    user.access_status = payload.access_status
    if payload.verification_note:
        user.verification_note = payload.verification_note
    db.commit()
    db.refresh(user)
    return user


@router.patch("/users/{user_id}/reject", response_model=UserResponse,
              summary="Reject a pending user [admin only]")
def reject_user(
    user_id: int,
    payload: RejectBody,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    user = _get_or_404(db, user_id)
    user.access_status = "rejected"
    if payload.reason:
        user.verification_note = payload.reason
    db.commit()
    db.refresh(user)
    return user


@router.patch("/users/{user_id}/block", response_model=UserResponse,
              summary="Block a user [admin only]")
def block_user(
    user_id: int,
    payload: BlockBody,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    user = _get_or_404(db, user_id)
    user.access_status = "deactivated"
    user.is_active = False
    if payload.reason:
        user.verification_note = payload.reason
    db.commit()
    db.refresh(user)
    return user


@router.patch("/users/{user_id}/unblock", response_model=UserResponse,
              summary="Unblock a user [admin only]")
def unblock_user(
    user_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    user = _get_or_404(db, user_id)
    user.access_status = "approved"
    user.is_active = True
    db.commit()
    db.refresh(user)
    return user


@router.delete("/users/{user_id}", status_code=204,
               summary="Permanently delete a user [admin only]")
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    user = _get_or_404(db, user_id)
    db.delete(user)
    db.commit()


# ── bulk operations ───────────────────────────────────────────────────────────

@router.post("/users/bulk-approve",
             summary="Approve multiple users and assign a role in one call [admin only]")
def bulk_approve_users(
    payload: BulkApproveBody,
    db: Session = Depends(get_db),
    current_user: User = Depends(admin_only),
):
    roles = _parse_role_strings([payload.role])
    _assert_can_assign_roles(current_user, roles)
    new_role = roles[0]

    approved = []
    not_found = []
    for uid in payload.user_ids:
        user = db.query(User).filter(User.id == uid).first()
        if not user:
            not_found.append(uid)
            continue
        _apply_roles(user, roles)
        user.access_status = payload.access_status
        if payload.verification_note:
            user.verification_note = payload.verification_note
        approved.append(uid)

    db.commit()
    return {"approved": approved, "not_found": not_found}


@router.post("/users/bulk-delete", status_code=200,
             summary="Permanently delete multiple users [admin only]")
def bulk_delete_users(
    payload: BulkDeleteBody,
    db: Session = Depends(get_db),
    current_user: User = Depends(admin_only),
):
    deleted = []
    not_found = []
    for uid in payload.user_ids:
        if uid == current_user.id:
            continue  # prevent self-deletion
        user = db.query(User).filter(User.id == uid).first()
        if not user:
            not_found.append(uid)
            continue
        db.delete(user)
        deleted.append(uid)
    db.commit()
    return {"deleted": deleted, "not_found": not_found}


# ── notifications ─────────────────────────────────────────────────────────────

@router.get("/notifications", summary="List admin notifications [admin only]")
def list_notifications(
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    notes = (
        db.query(AdminNotification)
        .order_by(AdminNotification.created_at.desc())
        .limit(50)
        .all()
    )
    return [_serialize_notification(n) for n in notes]


@router.patch("/notifications/{notification_id}/read",
              summary="Mark a notification as read [admin only]")
def mark_notification_read(
    notification_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    note = db.query(AdminNotification).filter(
        AdminNotification.id == notification_id
    ).first()
    if note:
        note.is_read = True
        db.commit()
    return {"ok": True}


@router.patch("/notifications/read-all",
              summary="Mark all notifications as read [admin only]")
def mark_all_read(
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    db.query(AdminNotification).filter(
        AdminNotification.is_read.is_(False)
    ).update({"is_read": True})
    db.commit()
    return {"ok": True}


# ── internal helpers ──────────────────────────────────────────────────────────

def _notify(db: Session, *, title: str, message: str,
            ntype: str = "general", user_id: int | None = None):
    note = AdminNotification(
        title=title,
        message=message,
        type=ntype,
        user_id=user_id,
    )
    db.add(note)


def _serialize_notification(n: AdminNotification) -> dict:
    return {
        "id":         n.id,
        "title":      n.title,
        "message":    n.message,
        "type":       n.type,
        "is_read":    n.is_read,
        "user_id":    n.user_id,
        "action_url": n.action_url,
        "created_at": n.created_at.isoformat() if n.created_at else None,
    }
