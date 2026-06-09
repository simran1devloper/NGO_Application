from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..crud import reward_crud
from ..database import get_db
from ..dependencies import admin_only, get_current_user, require_role, user_roles
from ..models.reward import RewardRule, RewardTask, RewardTrigger, UserMilestone, UserStreak
from ..models.user import User, UserRole
from ..schemas.reward import (
    RewardGiftCreate,
    RewardRuleCreate,
    RewardRuleResponse,
    RewardRuleUpdate,
    RewardSummaryResponse,
    RewardTaskCreate,
    RewardTaskProgress,
    RewardTaskResponse,
    RewardTransactionResponse,
    UserMilestoneResponse,
    UserStreakResponse,
)

router = APIRouter(prefix="/rewards", tags=["Rewards"])


def _assert_self_or_staff(current_user: User, user_id: int) -> None:
    if current_user.id == user_id:
        return
    roles = set(user_roles(current_user))
    if roles & {UserRole.mentor, UserRole.admin, UserRole.super_admin}:
        return
    raise HTTPException(status_code=403, detail="Access denied")


@router.get("/me", response_model=RewardSummaryResponse,
            summary="Get my reward wallet and history")
def my_rewards(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    total_points, total_xp = reward_crud.reward_totals(db, current_user.id)
    rewards = reward_crud.get_user_rewards(db, current_user.id)
    return RewardSummaryResponse(
        user_id=current_user.id,
        total_points=total_points,
        total_xp_from_rewards=total_xp,
        rewards=rewards,
    )


@router.get("/users/{user_id}", response_model=RewardSummaryResponse,
            summary="Get a user's rewards [self, mentor, admin]")
def user_rewards(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _assert_self_or_staff(current_user, user_id)
    total_points, total_xp = reward_crud.reward_totals(db, user_id)
    rewards = reward_crud.get_user_rewards(db, user_id)
    return RewardSummaryResponse(
        user_id=user_id,
        total_points=total_points,
        total_xp_from_rewards=total_xp,
        rewards=rewards,
    )


@router.post("/gift", response_model=RewardTransactionResponse, status_code=201,
             summary="Send reward points as a gift to another user")
def gift_reward(
    payload: RewardGiftCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if payload.recipient_id == current_user.id:
        raise HTTPException(status_code=422, detail="You cannot gift rewards to yourself")
    try:
        return reward_crud.create_transaction(
            db,
            user_id=payload.recipient_id,
            actor_id=current_user.id,
            points=payload.points,
            xp=0,
            trigger=RewardTrigger.gift,
            title=payload.title,
            message=payload.message,
            source_type="gift",
            source_id=current_user.id,
        )
    except ValueError:
        raise HTTPException(status_code=404, detail="Recipient not found")


@router.get("/rules", response_model=list[RewardRuleResponse],
            summary="List reward rules [admin only]")
def list_rules(
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    return db.query(RewardRule).order_by(RewardRule.role, RewardRule.trigger).all()


@router.post("/rules", response_model=RewardRuleResponse, status_code=201,
             summary="Create a role-specific reward rule [admin only]")
def create_rule(
    payload: RewardRuleCreate,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    rule = RewardRule(**payload.model_dump())
    db.add(rule)
    db.commit()
    db.refresh(rule)
    return rule


@router.patch("/rules/{rule_id}", response_model=RewardRuleResponse,
              summary="Update a reward rule [admin only]")
def update_rule(
    rule_id: int,
    payload: RewardRuleUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    rule = db.query(RewardRule).filter(RewardRule.id == rule_id).first()
    if not rule:
        raise HTTPException(status_code=404, detail="Reward rule not found")
    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(rule, field, value)
    db.commit()
    db.refresh(rule)
    return rule


@router.post("/tasks", response_model=RewardTaskResponse, status_code=201,
             summary="Assign a rewarded task [mentor, admin]")
def create_task(
    payload: RewardTaskCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.mentor, UserRole.admin, UserRole.super_admin)),
):
    return reward_crud.create_task(
        db,
        user_id=payload.user_id,
        created_by=current_user.id,
        title=payload.title,
        description=payload.description,
        target_count=payload.target_count,
        reward_points=payload.reward_points,
        reward_xp=payload.reward_xp,
        due_at=payload.due_at,
    )


@router.get("/tasks/me", response_model=list[RewardTaskResponse],
            summary="List my rewarded tasks")
def my_tasks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return (
        db.query(RewardTask)
        .filter(RewardTask.user_id == current_user.id)
        .order_by(RewardTask.created_at.desc())
        .all()
    )


@router.patch("/tasks/{task_id}/progress", response_model=RewardTaskResponse,
              summary="Advance task progress [task owner, mentor, admin]")
def advance_task(
    task_id: int,
    payload: RewardTaskProgress,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = db.query(RewardTask).filter(RewardTask.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    _assert_self_or_staff(current_user, task.user_id)
    return reward_crud.advance_task(db, task, payload.increment)


@router.get("/streak/me", response_model=UserStreakResponse,
            summary="Get the current user's streak")
def my_streak(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    streak = db.query(UserStreak).filter(UserStreak.user_id == current_user.id).first()
    if not streak:
        return UserStreakResponse(
            user_id=current_user.id,
            current_streak=0,
            longest_streak=0,
            last_activity_date=None,
            total_active_days=0,
        )
    return streak


@router.get("/milestones/me", response_model=list[UserMilestoneResponse],
            summary="Get the current user's achieved milestones")
def my_milestones(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return (
        db.query(UserMilestone)
        .filter(UserMilestone.user_id == current_user.id)
        .order_by(UserMilestone.achieved_at.desc())
        .all()
    )
