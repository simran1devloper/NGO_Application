import csv
import io
import json

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session

from ..crud import quiz_crud, reward_crud
from ..database import get_db
from ..dependencies import content_creator_or_above, get_current_user
from ..models.reward import RewardTrigger
from ..models.user import User, UserRole
from ..schemas.quiz import (
    AnswerResult,
    AttemptCreate,
    AttemptResponse,
    DailyChallengeResponse,
    QuestionCreate,
    QuestionResponse,
    QuestionUpdate,
    QuizCreate,
    QuizLeaderboardEntry,
    QuizResponse,
    QuizUpdate,
    QuizWithQuestions,
    SetDailyChallengeRequest,
)

router = APIRouter(prefix="/quizzes", tags=["Quizzes"])


def _can_manage_quizzes(user: User) -> bool:
    return user.role in (
        UserRole.content_creator,
        UserRole.mentor,
        UserRole.admin,
        UserRole.super_admin,
    )


def _ensure_quiz_visible_to_user(quiz, current_user: User):
    if quiz and not quiz.is_active and not _can_manage_quizzes(current_user):
        raise HTTPException(status_code=404, detail="Quiz not found")


def _build_attempt_response(attempt) -> AttemptResponse:
    qs = sorted(attempt.quiz.questions, key=lambda q: q.order_index)
    return AttemptResponse(
        id=attempt.id,
        quiz_id=attempt.quiz_id,
        score=attempt.score,
        correct_count=attempt.correct_count,
        total_questions=attempt.total_questions,
        xp_earned=attempt.xp_earned,
        time_taken_seconds=attempt.time_taken_seconds,
        completed_at=attempt.completed_at,
        answer_results=[
            AnswerResult(
                question_id=q.id,
                question_text=q.text,
                selected_index=attempt.answers[i] if i < len(attempt.answers) else -1,
                correct_index=q.correct_index,
                is_correct=(
                    attempt.answers[i] == q.correct_index
                    if i < len(attempt.answers) else False
                ),
                explanation=q.explanation,
            )
            for i, q in enumerate(qs)
        ],
    )


@router.get("/", response_model=list[QuizResponse],
            summary="List active quizzes [authenticated]")
def list_quizzes(
    category: str | None = None,
    include_inactive: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if include_inactive and current_user.role not in (
        UserRole.content_creator, UserRole.mentor, UserRole.admin, UserRole.super_admin
    ):
        raise HTTPException(status_code=403, detail="Access denied")
    return quiz_crud.list_quizzes(
        db, category=category, include_inactive=include_inactive
    )


@router.post("/", response_model=QuizResponse, status_code=201,
             summary="Create a quiz [admin/content_creator]")
def create_quiz(
    payload: QuizCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(content_creator_or_above),
):
    return quiz_crud.create_quiz(db, payload, current_user.id)


@router.get("/daily", response_model=DailyChallengeResponse,
            summary="Today's daily challenge [authenticated]")
def get_daily_challenge(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    dc = quiz_crud.get_today_challenge(db)
    if not dc:
        raise HTTPException(status_code=404, detail="No daily challenge today")
    _ensure_quiz_visible_to_user(dc.quiz, current_user)
    return DailyChallengeResponse(
        challenge_date=dc.challenge_date,
        quiz=QuizWithQuestions.model_validate(dc.quiz),
        completed=quiz_crud.has_completed_quiz(db, current_user.id, dc.quiz_id),
    )


@router.post("/daily", response_model=dict,
             summary="Set/update the daily challenge [admin/content_creator]")
def set_daily_challenge(
    payload: SetDailyChallengeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(content_creator_or_above),
):
    if not quiz_crud.get_quiz(db, payload.quiz_id):
        raise HTTPException(status_code=404, detail="Quiz not found")
    quiz_crud.set_daily_challenge(db, payload.quiz_id, payload.challenge_date)
    return {"status": "ok", "challenge_date": payload.challenge_date}


@router.get("/users/{user_id}/history", response_model=list[AttemptResponse],
            summary="Get a user's quiz attempt history [self, mentor, admin]")
def user_quiz_history(
    user_id: int,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.id != user_id and current_user.role not in (
        UserRole.mentor, UserRole.admin, UserRole.super_admin
    ):
        raise HTTPException(status_code=403, detail="Access denied")
    return [
        _build_attempt_response(a)
        for a in quiz_crud.get_user_attempts(db, user_id, limit=limit)
    ]


@router.get("/{quiz_id}", response_model=QuizWithQuestions,
            summary="Get a quiz with questions [authenticated]")
def get_quiz(
    quiz_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    quiz = quiz_crud.get_quiz(db, quiz_id)
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    _ensure_quiz_visible_to_user(quiz, current_user)
    return quiz


@router.patch("/{quiz_id}", response_model=QuizResponse,
              summary="Update a quiz [admin/content_creator]")
def update_quiz(
    quiz_id: int,
    payload: QuizUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(content_creator_or_above),
):
    quiz = quiz_crud.update_quiz(db, quiz_id, payload)
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    return quiz


@router.delete("/{quiz_id}", status_code=204,
               summary="Delete a quiz [admin/content_creator]")
def delete_quiz(
    quiz_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(content_creator_or_above),
):
    if not quiz_crud.delete_quiz(db, quiz_id):
        raise HTTPException(status_code=404, detail="Quiz not found")


@router.get("/{quiz_id}/questions", response_model=list[QuestionResponse],
            summary="List questions for a quiz [authenticated]")
def list_questions(
    quiz_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    questions = quiz_crud.list_questions(db, quiz_id)
    if questions is None:
        raise HTTPException(status_code=404, detail="Quiz not found")
    quiz = quiz_crud.get_quiz(db, quiz_id)
    _ensure_quiz_visible_to_user(quiz, current_user)
    return questions


@router.post("/{quiz_id}/questions", response_model=QuestionResponse, status_code=201,
             summary="Add a question [admin/content_creator]")
def add_question(
    quiz_id: int,
    payload: QuestionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(content_creator_or_above),
):
    question = quiz_crud.add_question(db, quiz_id, payload)
    if not question:
        raise HTTPException(status_code=404, detail="Quiz not found")
    return question


@router.patch("/{quiz_id}/questions/{question_id}", response_model=QuestionResponse,
              summary="Update a question [admin/content_creator]")
def update_question(
    quiz_id: int,
    question_id: int,
    payload: QuestionUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(content_creator_or_above),
):
    question = quiz_crud.update_question(db, quiz_id, question_id, payload)
    if not question:
        raise HTTPException(status_code=404, detail="Question not found")
    return question


@router.delete("/{quiz_id}/questions/{question_id}", status_code=204,
               summary="Remove a question [admin/content_creator]")
def delete_question(
    quiz_id: int,
    question_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(content_creator_or_above),
):
    if not quiz_crud.delete_question(db, quiz_id, question_id):
        raise HTTPException(status_code=404, detail="Question not found")


@router.post("/{quiz_id}/attempt", response_model=AttemptResponse, status_code=201,
             summary="Submit a quiz attempt [authenticated]")
def submit_attempt(
    quiz_id: int,
    payload: AttemptCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    quiz = quiz_crud.get_quiz(db, quiz_id)
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    _ensure_quiz_visible_to_user(quiz, current_user)
    result = quiz_crud.submit_attempt(
        db, current_user.id, quiz_id, payload.answers, payload.time_taken_seconds
    )
    if result is None:
        raise HTTPException(status_code=404, detail="Quiz not found")
    attempt, _questions = result
    if (attempt.score or 0) >= 60:
        reward_crud.award_rule_reward(
            db, user_id=current_user.id,
            trigger=RewardTrigger.quiz_passed,
            source_type="quiz", source_id=quiz_id,
            message=f"Quiz passed with {attempt.score:.0f}%",
        )
    return _build_attempt_response(attempt)


@router.post("/import", response_model=QuizResponse, status_code=201,
             summary="Import quiz questions from CSV or JSON file [content_creator+]")
async def import_quiz(
    file: UploadFile = File(...),
    title: str = Form(...),
    difficulty: str = Form(default="medium"),
    xp_reward: int = Form(default=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(content_creator_or_above),
):
    raw = await file.read()
    try:
        content = raw.decode("utf-8")
    except UnicodeDecodeError:
        raise HTTPException(status_code=400, detail="File must be UTF-8 encoded")

    fname = (file.filename or "").lower()

    if fname.endswith(".json"):
        try:
            data = json.loads(content)
            if not isinstance(data, list):
                raise HTTPException(status_code=400, detail="JSON must be an array of question objects")
            raw_questions = data
        except json.JSONDecodeError as exc:
            raise HTTPException(status_code=400, detail=f"Invalid JSON: {exc}")
    elif fname.endswith(".csv"):
        reader = csv.DictReader(io.StringIO(content))
        raw_questions = []
        for row in reader:
            options = [row[f"option_{c}"] for c in "abcd" if row.get(f"option_{c}", "").strip()]
            if not row.get("text", "").strip() or len(options) < 2:
                continue
            raw_questions.append({
                "text": row["text"].strip(),
                "options": options,
                "correct_index": int(row.get("correct_index", 0)),
                "explanation": row.get("explanation") or None,
                "points": int(row.get("points", 10)),
            })
    else:
        raise HTTPException(status_code=400, detail="Only .csv and .json files are supported")

    if not raw_questions:
        raise HTTPException(status_code=400, detail="No valid questions found in file")

    try:
        questions = [QuestionCreate(**q) for q in raw_questions]
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Question format error: {exc}")

    quiz_payload = QuizCreate(title=title, difficulty=difficulty, xp_reward=xp_reward)
    quiz = quiz_crud.create_quiz(db, quiz_payload, current_user.id)
    for idx, q in enumerate(questions):
        q.order_index = idx
        quiz_crud.add_question(db, quiz.id, q)
    db.refresh(quiz)
    return quiz


@router.get("/{quiz_id}/leaderboard", response_model=list[QuizLeaderboardEntry],
            summary="Top scores for a quiz [authenticated]")
def quiz_leaderboard(
    quiz_id: int,
    limit: int = 10,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    quiz = quiz_crud.get_quiz(db, quiz_id)
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    _ensure_quiz_visible_to_user(quiz, current_user)
    return [QuizLeaderboardEntry(**r)
            for r in quiz_crud.get_quiz_leaderboard(db, quiz_id, limit=limit)]
