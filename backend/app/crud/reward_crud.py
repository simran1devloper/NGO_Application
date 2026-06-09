"""
Gamification engine: rewards, streaks, and milestones.

Flow for every meaningful user action:
  1. award_rule_reward()  → creates RewardTransaction, updates user XP/level
  2. update_streak()      → updates UserStreak, fires streak_milestone if needed
  3. check_milestones()   → awards any newly-unlocked UserMilestone rewards

Role-specific amounts are driven by RewardRule rows in the DB.
If no matching rule exists, DEFAULT_REWARD_RULES are applied.
"""

from datetime import date, datetime

from sqlalchemy.orm import Session

from ..config import settings
from ..models.reward import (
    RewardRule,
    RewardTask,
    RewardTransaction,
    RewardTrigger,
    UserMilestone,
    UserStreak,
)
from ..models.user import User
from ..permissions import parse_roles


# ── Default reward amounts (points, xp, title) ───────────────────────────────

DEFAULT_REWARD_RULES: dict[RewardTrigger, tuple[int, int, str]] = {
    # student learning
    RewardTrigger.lesson_completed:   (10,  10,  "Lesson completed"),
    RewardTrigger.video_completed:    (15,  15,  "Video lesson completed"),
    RewardTrigger.course_completed:   (100, 100, "Course completed"),
    RewardTrigger.topic_completed:    (25,  25,  "Topic completed"),
    RewardTrigger.quiz_passed:        (20,  20,  "Quiz passed"),
    RewardTrigger.event_attended:     (10,  5,   "Event attended"),
    RewardTrigger.counselling_booked: (5,   5,   "Counselling session booked"),

    # creator / mentor creation
    RewardTrigger.lesson_created:     (20,  20,  "Lesson created"),
    RewardTrigger.course_created:     (50,  50,  "Course created"),
    RewardTrigger.resource_uploaded:  (10,  10,  "Resource uploaded"),
    RewardTrigger.post_approved:      (30,  20,  "Post approved"),
    RewardTrigger.event_published:    (25,  25,  "Event published"),

    # mentor
    RewardTrigger.session_conducted:  (40,  30,  "Counselling session conducted"),

    # tasks
    RewardTrigger.task_progress:      (2,   0,   "Task progress"),
    RewardTrigger.task_completed:     (50,  50,  "Task completed"),

    # gamification
    RewardTrigger.daily_login:        (5,   5,   "Daily login"),
    RewardTrigger.streak_milestone:   (0,   0,   "Streak milestone"),   # overridden per milestone
    RewardTrigger.xp_milestone:       (0,   0,   "XP milestone"),       # overridden per milestone

    # gift / manual (no default; caller provides amount)
    RewardTrigger.gift:               (0,   0,   "Gift"),
    RewardTrigger.manual:             (0,   0,   "Reward"),
}

# Streak milestone definitions: {days: (points, xp, title)}
STREAK_MILESTONES: dict[int, tuple[int, int, str]] = {
    7:   (50,  50,  "7-day streak!"),
    14:  (100, 100, "14-day streak!"),
    30:  (200, 200, "30-day streak!"),
    60:  (400, 300, "60-day streak!"),
    100: (750, 500, "100-day streak!"),
}

# XP milestone definitions: {xp_threshold: (points, title)}
XP_MILESTONES: dict[int, tuple[int, str]] = {
    100:  (20,  "100 XP reached!"),
    500:  (50,  "500 XP reached!"),
    1000: (100, "1,000 XP reached!"),
    5000: (250, "5,000 XP reached!"),
}

# Lesson/course count milestones: {count: (points, xp, key_prefix)}
LESSON_COUNT_MILESTONES: list[tuple[int, int, int, str]] = [
    (1,  15, 15, "First lesson completed!"),
    (10, 30, 30, "10 lessons completed!"),
    (25, 75, 50, "25 lessons completed!"),
    (50, 150,100, "50 lessons completed!"),
]

COURSE_COUNT_MILESTONES: list[tuple[int, int, int, str]] = [
    (1,  20, 20, "First course completed!"),
    (5,  100,75, "5 courses completed!"),
    (10, 200,150,"10 courses completed!"),
]

POST_COUNT_MILESTONES: list[tuple[int, int, int, str]] = [
    (1,  25, 20, "First post approved!"),
    (5,  75, 50, "5 posts approved!"),
    (10, 150,100,"10 posts approved!"),
]

SESSION_COUNT_MILESTONES: list[tuple[int, int, int, str]] = [
    (1,  30, 25, "First session conducted!"),
    (10, 100,75, "10 sessions conducted!"),
    (25, 200,150,"25 sessions conducted!"),
]


# ── Helpers ───────────────────────────────────────────────────────────────────

def _apply_xp(user: User, amount: int) -> int:
    """Add XP, recalculate level. Returns new XP total."""
    if amount <= 0:
        return user.xp or 0
    user.xp = max(0, (user.xp or 0) + amount)
    user.level = user.xp // settings.xp_per_level + 1
    return user.xp


def _rule_for_user(db: Session, user: User, trigger: RewardTrigger) -> tuple[int, int, str]:
    """Return (points, xp, title) for this user+trigger, using role-specific DB rule if set."""
    roles = [r.value for r in parse_roles(user.roles, user.role)]
    rule = (
        db.query(RewardRule)
        .filter(
            RewardRule.trigger == trigger,
            RewardRule.role.in_(roles),
            RewardRule.is_active == True,
        )
        .order_by(RewardRule.points.desc(), RewardRule.xp.desc())
        .first()
    )
    if rule:
        return rule.points, rule.xp, rule.title
    return DEFAULT_REWARD_RULES.get(trigger, (0, 0, trigger.value.replace("_", " ").title()))


def _milestone_exists(db: Session, user_id: int, key: str) -> bool:
    return (
        db.query(UserMilestone)
        .filter(UserMilestone.user_id == user_id, UserMilestone.milestone_key == key)
        .first()
    ) is not None


def _grant_milestone(
    db: Session,
    user_id: int,
    key: str,
    title: str,
    points: int,
    xp: int,
    description: str | None = None,
) -> None:
    """Create a UserMilestone and award its reward (idempotent by key)."""
    if _milestone_exists(db, user_id, key):
        return
    milestone = UserMilestone(
        user_id=user_id,
        milestone_key=key,
        title=title,
        description=description,
        points=points,
        xp=xp,
    )
    db.add(milestone)
    if points > 0 or xp > 0:
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            _apply_xp(user, xp)
        tx = RewardTransaction(
            user_id=user_id,
            points=points,
            xp=xp,
            trigger=RewardTrigger.xp_milestone,
            title=title,
            message=description,
            source_type="milestone",
            source_id=None,
        )
        db.add(tx)


# ── Core transaction creator ──────────────────────────────────────────────────

def create_transaction(
    db: Session,
    *,
    user_id: int,
    points: int,
    xp: int,
    trigger: RewardTrigger,
    title: str,
    actor_id: int | None = None,
    message: str | None = None,
    source_type: str | None = None,
    source_id: int | None = None,
    commit: bool = True,
) -> RewardTransaction:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise ValueError("User not found")
    reward = RewardTransaction(
        user_id=user_id,
        actor_id=actor_id,
        points=points,
        xp=xp,
        trigger=trigger,
        title=title,
        message=message,
        source_type=source_type,
        source_id=source_id,
    )
    db.add(reward)
    _apply_xp(user, xp)
    if commit:
        db.commit()
        db.refresh(reward)
    return reward


# ── Deduplication-aware awarding ──────────────────────────────────────────────

def award_rule_reward(
    db: Session,
    *,
    user_id: int,
    trigger: RewardTrigger,
    source_type: str,
    source_id: int,
    message: str | None = None,
    actor_id: int | None = None,
    run_streak: bool = True,
    run_milestones: bool = True,
) -> RewardTransaction | None:
    """
    Award a reward for trigger+source (idempotent by source_type+source_id).

    Optionally updates the streak and checks milestones after awarding.
    """
    existing = (
        db.query(RewardTransaction)
        .filter(
            RewardTransaction.user_id == user_id,
            RewardTransaction.trigger == trigger,
            RewardTransaction.source_type == source_type,
            RewardTransaction.source_id == source_id,
        )
        .first()
    )
    if existing:
        return None

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return None

    points, xp, title = _rule_for_user(db, user, trigger)
    if points <= 0 and xp <= 0:
        return None

    tx = create_transaction(
        db,
        user_id=user_id,
        points=points,
        xp=xp,
        trigger=trigger,
        title=title,
        message=message,
        actor_id=actor_id,
        source_type=source_type,
        source_id=source_id,
        commit=False,
    )
    db.flush()

    if run_streak:
        update_streak(db, user_id, commit=False)
    if run_milestones:
        check_milestones(db, user_id, commit=False)

    db.commit()
    db.refresh(tx)
    return tx


# ── Streak engine ─────────────────────────────────────────────────────────────

def update_streak(db: Session, user_id: int, commit: bool = True) -> UserStreak:
    """
    Update user's activity streak for today.

    - First action of a new day: increment streak (or reset to 1 if more than 1 day gap).
    - Already active today: no-op on streak count.
    - Awards streak_milestone bonus at 7, 14, 30, 60, 100 days.
    """
    today = date.today()
    streak = (
        db.query(UserStreak)
        .filter(UserStreak.user_id == user_id)
        .first()
    )
    if streak is None:
        streak = UserStreak(
            user_id=user_id,
            current_streak=1,
            longest_streak=1,
            last_activity_date=today,
            total_active_days=1,
        )
        db.add(streak)
        if commit:
            db.commit()
            db.refresh(streak)
        return streak

    if streak.last_activity_date == today:
        return streak  # already counted today

    yesterday = (datetime.combine(today, datetime.min.time()) -
                 __import__("datetime").timedelta(days=1)).date()

    if streak.last_activity_date == yesterday:
        streak.current_streak += 1
    else:
        streak.current_streak = 1  # gap — reset

    streak.last_activity_date = today
    streak.total_active_days = (streak.total_active_days or 0) + 1
    if streak.current_streak > (streak.longest_streak or 0):
        streak.longest_streak = streak.current_streak

    # Check streak milestone bonuses
    milestone_days = streak.current_streak
    if milestone_days in STREAK_MILESTONES:
        pts, xp_val, m_title = STREAK_MILESTONES[milestone_days]
        key = f"streak_{milestone_days}d"
        if not _milestone_exists(db, user_id, key):
            user = db.query(User).filter(User.id == user_id).first()
            if user:
                _apply_xp(user, xp_val)
            milestone = UserMilestone(
                user_id=user_id,
                milestone_key=key,
                title=m_title,
                description=f"Maintained a {milestone_days}-day activity streak",
                points=pts,
                xp=xp_val,
            )
            db.add(milestone)
            if pts > 0 or xp_val > 0:
                tx = RewardTransaction(
                    user_id=user_id,
                    points=pts,
                    xp=xp_val,
                    trigger=RewardTrigger.streak_milestone,
                    title=m_title,
                    message=f"You hit a {milestone_days}-day streak!",
                    source_type="streak_milestone",
                    source_id=milestone_days,
                )
                db.add(tx)

    if commit:
        db.commit()
        db.refresh(streak)
    return streak


# ── Milestone checker ─────────────────────────────────────────────────────────

def check_milestones(db: Session, user_id: int, commit: bool = True) -> None:
    """Check and award any newly-unlocked milestones after a reward event."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return

    # XP milestones
    current_xp = user.xp or 0
    for threshold, (pts, m_title) in XP_MILESTONES.items():
        if current_xp >= threshold:
            key = f"xp_{threshold}"
            _grant_milestone(db, user_id, key, m_title, pts, 0,
                             description=f"You reached {threshold:,} XP")

    # Count-based milestones from transaction history
    def _count_trigger(trigger: RewardTrigger) -> int:
        return (
            db.query(RewardTransaction)
            .filter(RewardTransaction.user_id == user_id, RewardTransaction.trigger == trigger)
            .count()
        )

    lessons_done = _count_trigger(RewardTrigger.lesson_completed) + _count_trigger(RewardTrigger.video_completed)
    for n, pts, xp_val, m_title in LESSON_COUNT_MILESTONES:
        if lessons_done >= n:
            _grant_milestone(db, user_id, f"lessons_{n}", m_title, pts, xp_val)

    courses_done = _count_trigger(RewardTrigger.course_completed)
    for n, pts, xp_val, m_title in COURSE_COUNT_MILESTONES:
        if courses_done >= n:
            _grant_milestone(db, user_id, f"courses_{n}", m_title, pts, xp_val)

    posts_approved = _count_trigger(RewardTrigger.post_approved)
    for n, pts, xp_val, m_title in POST_COUNT_MILESTONES:
        if posts_approved >= n:
            _grant_milestone(db, user_id, f"posts_{n}", m_title, pts, xp_val)

    sessions = _count_trigger(RewardTrigger.session_conducted)
    for n, pts, xp_val, m_title in SESSION_COUNT_MILESTONES:
        if sessions >= n:
            _grant_milestone(db, user_id, f"sessions_{n}", m_title, pts, xp_val)

    if commit:
        try:
            db.commit()
        except Exception:
            db.rollback()


# ── Simple accessors ──────────────────────────────────────────────────────────

def get_user_rewards(db: Session, user_id: int, limit: int = 100) -> list[RewardTransaction]:
    return (
        db.query(RewardTransaction)
        .filter(RewardTransaction.user_id == user_id)
        .order_by(RewardTransaction.created_at.desc())
        .limit(limit)
        .all()
    )


def reward_totals(db: Session, user_id: int) -> tuple[int, int]:
    rewards = db.query(RewardTransaction).filter(RewardTransaction.user_id == user_id).all()
    return sum(r.points for r in rewards), sum(r.xp for r in rewards)


def get_streak(db: Session, user_id: int) -> UserStreak | None:
    return db.query(UserStreak).filter(UserStreak.user_id == user_id).first()


def get_milestones(db: Session, user_id: int) -> list[UserMilestone]:
    return (
        db.query(UserMilestone)
        .filter(UserMilestone.user_id == user_id)
        .order_by(UserMilestone.achieved_at.desc())
        .all()
    )


# ── Task helpers ──────────────────────────────────────────────────────────────

def create_task(
    db: Session,
    *,
    user_id: int,
    created_by: int | None,
    title: str,
    description: str | None,
    target_count: int,
    reward_points: int,
    reward_xp: int,
    due_at,
) -> RewardTask:
    task = RewardTask(
        user_id=user_id,
        created_by=created_by,
        title=title,
        description=description,
        target_count=target_count,
        reward_points=reward_points,
        reward_xp=reward_xp,
        due_at=due_at,
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


def advance_task(db: Session, task: RewardTask, increment: int) -> RewardTask:
    if task.status == "completed":
        return task
    task.current_count = min(task.target_count, task.current_count + increment)
    if task.current_count >= task.target_count:
        task.status = "completed"
        task.completed_at = datetime.now()
        create_transaction(
            db,
            user_id=task.user_id,
            actor_id=task.created_by,
            points=task.reward_points,
            xp=task.reward_xp,
            trigger=RewardTrigger.task_completed,
            title=f"Task completed: {task.title}",
            source_type="reward_task",
            source_id=task.id,
            commit=False,
        )
    else:
        create_transaction(
            db,
            user_id=task.user_id,
            actor_id=task.created_by,
            points=DEFAULT_REWARD_RULES[RewardTrigger.task_progress][0],
            xp=0,
            trigger=RewardTrigger.task_progress,
            title=f"Task progress: {task.title}",
            source_type="reward_task_progress",
            source_id=task.id,
            commit=False,
        )
    update_streak(db, task.user_id, commit=False)
    check_milestones(db, task.user_id, commit=False)
    db.commit()
    db.refresh(task)
    return task
