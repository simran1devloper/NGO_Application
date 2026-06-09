from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..crud import user_crud
from ..database import get_db
from ..dependencies import admin_only, get_current_user, require_role
from ..models.user import User, UserRole
from ..permissions import serialize_roles
from ..schemas.user import (
    UserCreate,
    UserResponse,
    UserRoleUpdate,
    UserStats,
    UserStatusUpdate,
    UserUpdate,
    XPAdd,
)

router = APIRouter(prefix="/users", tags=["Users"])


# ── helpers ────────────────────────────────────────────────────────────────────

def _assert_self_or_admin(current_user: User, target_id: int) -> None:
    """Raise 403 if the caller is neither the target user nor an admin/super_admin."""
    if current_user.id != target_id and current_user.role not in (
        UserRole.admin, UserRole.super_admin
    ):
        raise HTTPException(status_code=403, detail="Access denied")


# ── routes ─────────────────────────────────────────────────────────────────────

@router.get("/", response_model=list[UserResponse],
            summary="List all users [admin only]")
def list_users(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    return user_crud.get_users(db, skip=skip, limit=limit)


@router.post("/", response_model=UserResponse, status_code=201,
             summary="Create a user without a password [admin only]")
def create_user(
    payload: UserCreate,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    return user_crud.create_user(db, payload)


@router.patch("/me/profile", response_model=UserResponse,
              summary="Update the current user's student profile fields")
def update_my_profile(
    payload: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = user_crud.update_user(db, current_user.id, payload)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.get("/{user_id}", response_model=UserResponse,
            summary="Get a user profile [self or admin]")
def get_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _assert_self_or_admin(current_user, user_id)
    user = user_crud.get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.patch("/{user_id}", response_model=UserResponse,
              summary="Update a user's own profile fields [self or admin]")
def update_user(
    user_id: int,
    payload: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _assert_self_or_admin(current_user, user_id)
    user = user_crud.update_user(db, user_id, payload)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.patch("/{user_id}/role", response_model=UserResponse,
              summary="Assign a role to a user [admin only]")
def assign_role(
    user_id: int,
    payload: UserRoleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(admin_only),
):
    """
    Admins may assign any role up to (but not including) super_admin.
    Only super_admin can promote another user to super_admin.
    """
    if payload.role == UserRole.super_admin and current_user.role != UserRole.super_admin:
        raise HTTPException(
            status_code=403,
            detail="Only super_admin can assign the super_admin role",
        )
    user = user_crud.get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.role = payload.role
    user.roles = serialize_roles([payload.role])
    db.commit()
    db.refresh(user)
    return user


@router.patch("/{user_id}/status", response_model=UserResponse,
              summary="Activate or deactivate (block) a user account [admin only]")
def set_user_status(
    user_id: int,
    payload: UserStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(admin_only),
):
    user = user_crud.get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = payload.is_active
    db.commit()
    db.refresh(user)
    return user


@router.post("/{user_id}/xp", response_model=UserResponse,
             summary="Award XP to a user [mentor or admin]")
def add_xp(
    user_id: int,
    payload: XPAdd,
    db: Session = Depends(get_db),
    _: User = Depends(require_role(UserRole.mentor, UserRole.admin, UserRole.super_admin)),
):
    user = user_crud.add_xp(db, user_id, payload.amount)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.get("/{user_id}/stats", response_model=UserStats,
            summary="Get learning stats [self, mentor, or admin]")
def get_stats(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _assert_self_or_admin(current_user, user_id)
    stats = user_crud.get_user_stats(db, user_id)
    if not stats:
        raise HTTPException(status_code=404, detail="User not found")
    return stats
