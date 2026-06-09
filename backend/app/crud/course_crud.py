from datetime import datetime

from sqlalchemy.orm import Session

from ..models.course import Course, Lesson, LearningResource, SkillCategory, UserCourseProgress, UserLessonProgress
from ..schemas.course import (
    CategoryCreate,
    CategoryUpdate,
    CourseCreate,
    CourseUpdate,
    CourseDetailResponse,
    LearningResourceCreate,
    LearningResourceDetailResponse,
    LearningResourceUpdate,
    LessonCreate,
    LessonDetailResponse,
    LessonResponse,
    LessonUpdate,
)


def create_course(db: Session, data: CourseCreate) -> Course:
    course = Course(**data.model_dump())
    db.add(course)
    db.commit()
    db.refresh(course)
    return course


def update_course(db: Session, course_id: int, data: CourseUpdate) -> Course | None:
    course = db.query(Course).filter(Course.id == course_id).first()
    if not course:
        return None
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(course, field, value)
    db.commit()
    db.refresh(course)
    return course


def delete_course(db: Session, course_id: int) -> bool:
    course = db.query(Course).filter(Course.id == course_id).first()
    if not course:
        return False
    db.delete(course)
    db.commit()
    return True


def get_categories(db: Session) -> list[SkillCategory]:
    return db.query(SkillCategory).all()


def create_category(db: Session, data: CategoryCreate) -> SkillCategory:
    category = SkillCategory(**data.model_dump())
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


def update_category(
    db: Session, category_id: int, data: CategoryUpdate
) -> SkillCategory | None:
    category = db.query(SkillCategory).filter(SkillCategory.id == category_id).first()
    if not category:
        return None
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(category, field, value)
    db.commit()
    db.refresh(category)
    return category


def delete_category(db: Session, category_id: int) -> bool:
    category = db.query(SkillCategory).filter(SkillCategory.id == category_id).first()
    if not category:
        return False
    db.query(Course).filter(Course.category_id == category_id).update(
        {Course.category_id: None}
    )
    db.delete(category)
    db.commit()
    return True


def get_courses(db: Session, skip: int = 0, limit: int = 100) -> list[Course]:
    return db.query(Course).offset(skip).limit(limit).all()


def get_course(db: Session, course_id: int) -> Course | None:
    return db.query(Course).filter(Course.id == course_id).first()


def get_course_detail(
    db: Session,
    course_id: int,
    user_id: int | None = None,
    include_unpublished: bool = False,
) -> CourseDetailResponse | None:
    course = get_course(db, course_id)
    if not course:
        return None

    lesson_query = db.query(Lesson).filter(Lesson.course_id == course_id)
    if not include_unpublished:
        lesson_query = lesson_query.filter(Lesson.is_published == True)
    lessons = lesson_query.order_by(Lesson.order).all()

    completed_ids: set[int] = set()
    progress = 0
    if user_id is not None:
        completed_ids = {
            row.lesson_id
            for row in db.query(UserLessonProgress).filter(
                UserLessonProgress.user_id == user_id,
                UserLessonProgress.completed == True,
            ).all()
        }
        total = len([lesson for lesson in lessons if lesson.is_published])
        if total:
            done = len(
                [
                    lesson
                    for lesson in lessons
                    if lesson.is_published and lesson.id in completed_ids
                ]
            )
            progress = round((done / total) * 100)

    preview_video_url = next(
        (
            lesson.content_url
            for lesson in lessons
            if lesson.content_type == "video" and lesson.content_url
        ),
        None,
    )

    return CourseDetailResponse(
        id=course.id,
        title=course.title,
        description=f"Learn {course.title.lower()} step by step.",
        difficulty=course.level,
        duration_minutes=None,
        duration=course.duration,
        progress=progress,
        preview_video_url=preview_video_url,
        lessons=[
            LessonDetailResponse(
                id=lesson.id,
                title=lesson.title,
                description=lesson.description,
                content_type=lesson.content_type,
                content=lesson.content_text,
                video_url=lesson.content_url,
                duration_minutes=lesson.duration_minutes,
                is_completed=lesson.id in completed_ids,
                is_published=lesson.is_published,
                resources=[
                    LearningResourceDetailResponse(
                        id=resource.id,
                        name=resource.title,
                        type=resource.type,
                        url=resource.file_url,
                        size=None,
                    )
                    for resource in lesson.resources
                ],
            )
            for lesson in lessons
        ],
    )


def get_user_course_progress(db: Session, user_id: int) -> list[UserCourseProgress]:
    return (
        db.query(UserCourseProgress)
        .filter(UserCourseProgress.user_id == user_id)
        .all()
    )


def upsert_course_progress(
    db: Session, user_id: int, course_id: int, progress: float
) -> UserCourseProgress:
    record = (
        db.query(UserCourseProgress)
        .filter(
            UserCourseProgress.user_id == user_id,
            UserCourseProgress.course_id == course_id,
        )
        .first()
    )
    if record is None:
        record = UserCourseProgress(
            user_id=user_id,
            course_id=course_id,
            progress=progress,
            completed=progress >= 1.0,
        )
        db.add(record)
    else:
        record.progress = progress
        record.completed = progress >= 1.0
    db.commit()
    db.refresh(record)
    return record


# ── Lesson CRUD ────────────────────────────────────────────────────────────────

def _build_lesson_response(lesson: Lesson, completed: bool = False) -> LessonResponse:
    return LessonResponse(
        id=lesson.id,
        course_id=lesson.course_id,
        title=lesson.title,
        description=lesson.description,
        content_type=lesson.content_type,
        content_url=lesson.content_url,
        content_text=lesson.content_text,
        order=lesson.order,
        duration_minutes=lesson.duration_minutes,
        is_published=lesson.is_published,
        completed=completed,
    )


def get_lessons(db: Session, course_id: int, user_id: int | None = None) -> list[LessonResponse]:
    lessons = (
        db.query(Lesson)
        .filter(Lesson.course_id == course_id, Lesson.is_published == True)
        .order_by(Lesson.order)
        .all()
    )
    if not user_id:
        return [_build_lesson_response(l) for l in lessons]

    completed_ids = {
        row.lesson_id
        for row in db.query(UserLessonProgress).filter(
            UserLessonProgress.user_id == user_id,
            UserLessonProgress.completed == True,
        ).all()
    }
    return [_build_lesson_response(l, completed=l.id in completed_ids) for l in lessons]


def get_all_lessons_admin(db: Session, course_id: int) -> list[LessonResponse]:
    lessons = (
        db.query(Lesson)
        .filter(Lesson.course_id == course_id)
        .order_by(Lesson.order)
        .all()
    )
    return [_build_lesson_response(l) for l in lessons]


def create_lesson(db: Session, course_id: int, data: LessonCreate) -> Lesson:
    lesson = Lesson(course_id=course_id, **data.model_dump())
    db.add(lesson)
    db.commit()
    db.refresh(lesson)
    return lesson


def update_lesson(db: Session, lesson_id: int, data: LessonUpdate) -> Lesson | None:
    lesson = db.query(Lesson).filter(Lesson.id == lesson_id).first()
    if not lesson:
        return None
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(lesson, field, value)
    db.commit()
    db.refresh(lesson)
    return lesson


def delete_lesson(db: Session, lesson_id: int) -> bool:
    lesson = db.query(Lesson).filter(Lesson.id == lesson_id).first()
    if not lesson:
        return False
    db.delete(lesson)
    db.commit()
    return True


def mark_lesson_complete(db: Session, user_id: int, lesson_id: int) -> None:
    record = (
        db.query(UserLessonProgress)
        .filter(
            UserLessonProgress.user_id == user_id,
            UserLessonProgress.lesson_id == lesson_id,
        )
        .first()
    )
    was_completed = bool(record and record.completed)
    if record is None:
        record = UserLessonProgress(
            user_id=user_id,
            lesson_id=lesson_id,
            completed=True,
            completed_at=datetime.now(),
        )
        db.add(record)
    else:
        record.completed = True
        record.completed_at = datetime.now()
    db.commit()

    # Recompute course progress automatically
    lesson = db.query(Lesson).filter(Lesson.id == lesson_id).first()
    if lesson:
        if not was_completed:
            from . import reward_crud
            from ..models.reward import RewardTrigger

            trigger = (
                RewardTrigger.video_completed
                if lesson.content_type == "video"
                else RewardTrigger.lesson_completed
            )
            reward_crud.award_rule_reward(
                db,
                user_id=user_id,
                trigger=trigger,
                source_type="lesson",
                source_id=lesson.id,
                message=lesson.title,
            )
        _recompute_course_progress(db, user_id, lesson.course_id)


# ── LearningResource CRUD ──────────────────────────────────────────────────────

def get_resources(db: Session, lesson_id: int) -> list[LearningResource]:
    return (
        db.query(LearningResource)
        .filter(LearningResource.lesson_id == lesson_id)
        .order_by(LearningResource.id)
        .all()
    )


def create_resource(
    db: Session, lesson_id: int, data: LearningResourceCreate, uploaded_by: int
) -> LearningResource:
    resource = LearningResource(
        lesson_id=lesson_id,
        uploaded_by=uploaded_by,
        **data.model_dump(),
    )
    db.add(resource)
    db.commit()
    db.refresh(resource)
    return resource


def update_resource(
    db: Session, resource_id: int, data: LearningResourceUpdate
) -> LearningResource | None:
    resource = db.query(LearningResource).filter(LearningResource.id == resource_id).first()
    if not resource:
        return None
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(resource, field, value)
    db.commit()
    db.refresh(resource)
    return resource


def delete_resource(db: Session, resource_id: int) -> bool:
    resource = db.query(LearningResource).filter(LearningResource.id == resource_id).first()
    if not resource:
        return False
    db.delete(resource)
    db.commit()
    return True


def _recompute_course_progress(db: Session, user_id: int, course_id: int) -> None:
    total = (
        db.query(Lesson)
        .filter(Lesson.course_id == course_id, Lesson.is_published == True)
        .count()
    )
    if total == 0:
        return
    completed_count = (
        db.query(UserLessonProgress)
        .join(Lesson, UserLessonProgress.lesson_id == Lesson.id)
        .filter(
            UserLessonProgress.user_id == user_id,
            UserLessonProgress.completed == True,
            Lesson.course_id == course_id,
            Lesson.is_published == True,
        )
        .count()
    )
    progress = completed_count / total
    record = upsert_course_progress(db, user_id, course_id, progress)
    if record.completed:
        from . import reward_crud
        from ..models.reward import RewardTrigger

        reward_crud.award_rule_reward(
            db,
            user_id=user_id,
            trigger=RewardTrigger.course_completed,
            source_type="course",
            source_id=course_id,
        )
