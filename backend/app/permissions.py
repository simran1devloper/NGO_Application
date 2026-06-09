"""
Permission constants, role-permission mapping, and role ordering for CareSkill RBAC.

Admin hierarchy (only these two are hierarchical):
  admin → super_admin

Feature roles are additive — a user with multiple feature roles gets the UNION of
all their role permissions. Combine roles (e.g. mediator + content_creator) to
extend what a user can do.

Feature role summary:
  content_creator — create/edit/publish events, lessons, quizzes, safety questions
  mentor          — all content_creator features + counselling management + XP/badge awards
  mediator        — moderation of posts, comments, reviews + analytics
  event_manager   — create/edit/publish/delete events only
  support_staff   — manage safety questions + emergency contacts + view analytics
"""

from enum import Enum

from .models.user import UserRole


# Ordered only for choosing a primary/display role. Feature access is not
# hierarchical; admin/super_admin are the only inherited management roles.
ROLE_HIERARCHY: list[UserRole] = [
    UserRole.guest,
    UserRole.student,
    UserRole.support_staff,
    UserRole.event_manager,
    UserRole.content_creator,
    UserRole.mentor,
    UserRole.mediator,
    UserRole.admin,
    UserRole.super_admin,
]

ADMIN_ROLES: frozenset[UserRole] = frozenset({
    UserRole.admin,
    UserRole.super_admin,
})


class Permission(str, Enum):
    # ── user management ───────────────────────────────────────────────────────
    MANAGE_USERS = "manage_users"           # list all users, deactivate accounts
    ASSIGN_ROLE  = "assign_role"            # change another user's role

    # ── event management ──────────────────────────────────────────────────────
    CREATE_EVENT  = "create_event"
    EDIT_EVENT    = "edit_event"
    PUBLISH_EVENT = "publish_event"
    DELETE_EVENT  = "delete_event"

    # ── learning content ──────────────────────────────────────────────────────
    CREATE_LESSON     = "create_lesson"
    EDIT_LESSON       = "edit_lesson"
    DELETE_LESSON     = "delete_lesson"
    MANAGE_CATEGORIES = "manage_categories"

    # ── counselling ───────────────────────────────────────────────────────────
    MANAGE_COUNSELLING = "manage_counselling"   # create/edit mentor profiles
    VIEW_ANALYTICS     = "view_analytics"       # booking analytics dashboard

    # ── gamification ──────────────────────────────────────────────────────────
    AWARD_BADGES = "award_badges"
    AWARD_XP     = "award_xp"

    # ── quiz & safety ──────────────────────────────────────────────────────────
    CREATE_QUIZ               = "create_quiz"
    MANAGE_SAFETY_QUESTIONS   = "manage_safety_questions"
    MANAGE_EMERGENCY_CONTACTS = "manage_emergency_contacts"

    # ── moderation (mediator+) ────────────────────────────────────────────────
    MODERATE_CONTENT  = "moderate_content"    # approve/reject posts and events
    MODERATE_COMMENTS = "moderate_comments"   # hide/unhide flagged comments
    MODERATE_REVIEWS  = "moderate_reviews"    # approve/reject user reviews


# Explicit permission sets per role.
# Note: these are NOT automatically cumulative. Multi-role users receive the
# union of their assigned feature roles.
ROLE_PERMISSIONS: dict[UserRole, frozenset] = {
    UserRole.guest: frozenset(),

    UserRole.student: frozenset(),

    UserRole.content_creator: frozenset({
        Permission.CREATE_EVENT,
        Permission.EDIT_EVENT,
        Permission.PUBLISH_EVENT,
        Permission.CREATE_LESSON,
        Permission.EDIT_LESSON,
        Permission.DELETE_LESSON,
        Permission.CREATE_QUIZ,
        Permission.MANAGE_SAFETY_QUESTIONS,
    }),

    # Mentor adds counselling management, analytics, and XP/badge award on top
    # of content_creator's permissions.
    UserRole.mentor: frozenset({
        Permission.CREATE_EVENT,
        Permission.EDIT_EVENT,
        Permission.PUBLISH_EVENT,
        Permission.CREATE_LESSON,
        Permission.EDIT_LESSON,
        Permission.DELETE_LESSON,
        Permission.CREATE_QUIZ,
        Permission.MANAGE_SAFETY_QUESTIONS,
        Permission.MANAGE_COUNSELLING,
        Permission.VIEW_ANALYTICS,
        Permission.AWARD_BADGES,
        Permission.AWARD_XP,
    }),

    # Mediator: moderation + analytics — no user management or admin tools.
    # For content creation ability, assign mediator + content_creator roles together.
    UserRole.mediator: frozenset({
        Permission.MODERATE_CONTENT,
        Permission.MODERATE_COMMENTS,
        Permission.MODERATE_REVIEWS,
        Permission.VIEW_ANALYTICS,
    }),

    # Event manager: full event lifecycle management only.
    UserRole.event_manager: frozenset({
        Permission.CREATE_EVENT,
        Permission.EDIT_EVENT,
        Permission.PUBLISH_EVENT,
        Permission.DELETE_EVENT,
        Permission.VIEW_ANALYTICS,
    }),

    # Support staff: user safety and emergency support.
    UserRole.support_staff: frozenset({
        Permission.MANAGE_SAFETY_QUESTIONS,
        Permission.MANAGE_EMERGENCY_CONTACTS,
        Permission.VIEW_ANALYTICS,
        Permission.MODERATE_COMMENTS,
    }),

    # Admin and super_admin have every permission.
    UserRole.admin:       frozenset(Permission),
    UserRole.super_admin: frozenset(Permission),
}


def has_permission(role: UserRole, permission: Permission) -> bool:
    """Return True if the given role has the specified permission."""
    return permission in ROLE_PERMISSIONS.get(role, frozenset())


# ── Multi-role helpers ────────────────────────────────────────────────────────

import json  # noqa: E402


def parse_roles(roles_json: str | None, primary_role: UserRole) -> list[UserRole]:
    """Return the full list of roles a user holds (always includes primary role)."""
    if not roles_json:
        return [primary_role]
    try:
        raw = json.loads(roles_json)
        roles = []
        for r in raw:
            try:
                roles.append(UserRole(r))
            except ValueError:
                pass
        if primary_role not in roles:
            roles.insert(0, primary_role)
        return roles
    except (ValueError, TypeError):
        return [primary_role]


def highest_role(roles: list[UserRole]) -> UserRole:
    """Return the highest-privilege role in the list."""
    if not roles:
        return UserRole.guest
    return max(roles, key=lambda r: ROLE_HIERARCHY.index(r) if r in ROLE_HIERARCHY else -1)


def serialize_roles(roles: list[UserRole]) -> str:
    deduped = list(dict.fromkeys(roles))
    return json.dumps([r.value for r in deduped])
