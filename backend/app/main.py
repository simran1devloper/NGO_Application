from pathlib import Path
import mimetypes

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response, StreamingResponse
from fastapi.staticfiles import StaticFiles

from .config import settings
from .logging_config import setup_logging

setup_logging(level="INFO")
from .database import engine
from .models import (  # noqa: F401 — registers all ORM models before create_all
    Badge, BlacklistedToken, Course, CounsellingAvailability, CounsellingSession,
    CounsellingNotification, MentorProfile,
    Event, EventParticipant, EventQuiz, EventSelection, EventSlot,
    Lesson, SkillCategory, User, UserBadge, UserCourseProgress, UserLessonProgress,
    Quiz, Question, QuizAttempt, DailyChallenge,
    SafetyAwarenessQuestion, UserSafetyAnswer,
    EmergencyContact,
    ChatMessage,
    AdminNotification,
    StudentReminder,
    RewardRule, RewardTask, RewardTransaction,
    CreatorPost,
    Donation, Payment, Feedback, DiscountCode, Reaction, Comment, Review,
)
from .database import Base
from .dev_migrations import ensure_sqlite_schema
from .middleware.rbac_logging import RBACLoggingMiddleware
from .routers import admin, auth, badges, courses, leaderboard, users, wellness
from .routers import counselling
from .routers import events
from .routers import quiz
from .routers import safety
from .routers import emergency
from .routers import chat
from .routers import creator
from .routers import upload
from .routers import calendar
from .routers import donation
from .routers import payment
from .routers import feedback
from .routers import discount
from .routers import reaction
from .routers import comment
from .routers import review
from .routers import moderation
from .routers import rewards

Base.metadata.create_all(bind=engine)
ensure_sqlite_schema(engine)

app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    debug=settings.debug,
)

# ── middleware (order matters: outermost first) ────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RBACLoggingMiddleware)


# Tells ngrok to set a browser cookie that permanently skips the free-tier
# interstitial warning page for this domain.
@app.middleware("http")
async def ngrok_skip_warning(request, call_next):
    response = await call_next(request)
    response.headers["ngrok-skip-browser-warning"] = "true"
    return response

# ── routers ────────────────────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(users.router)
app.include_router(courses.router)
app.include_router(wellness.router)
app.include_router(counselling.router)
app.include_router(badges.router)
app.include_router(leaderboard.router)
app.include_router(events.router)
app.include_router(events.root_router)
app.include_router(quiz.router)
app.include_router(safety.router)
app.include_router(emergency.router)
app.include_router(chat.router)
app.include_router(creator.router)
app.include_router(upload.router)
app.include_router(calendar.router)
app.include_router(donation.router)
app.include_router(payment.router)
app.include_router(feedback.router)
app.include_router(discount.router)
app.include_router(reaction.router)
app.include_router(comment.router)
app.include_router(review.router)
app.include_router(moderation.router)
app.include_router(rewards.router)


@app.get("/health", tags=["Health"])
def health():
    return {"status": "ok", "app": settings.app_name, "version": settings.version}


# ── Uploaded files static serving ─────────────────────────────────────────────
_uploads_dir = Path(__file__).parent.parent / "uploads"
_uploads_dir.mkdir(exist_ok=True)


@app.api_route(
    "/uploads/{filename}",
    methods=["GET", "HEAD"],
    include_in_schema=False,
)
async def serve_upload(filename: str, request: Request):
    upload_path = _uploads_dir / filename
    if not upload_path.is_file() or upload_path.parent != _uploads_dir:
        raise HTTPException(status_code=404, detail="Not Found")

    content_type = (
        mimetypes.guess_type(upload_path.name)[0] or "application/octet-stream"
    )
    file_size = upload_path.stat().st_size
    disposition = "attachment" if request.query_params.get("download") else "inline"
    requested_name = request.query_params.get("filename") or upload_path.name
    response_filename = Path(requested_name).name.replace('"', "")
    headers = {
        "Accept-Ranges": "bytes",
        "Content-Disposition": f'{disposition}; filename="{response_filename}"',
    }

    range_header = request.headers.get("range")
    if not range_header:
        if request.method == "HEAD":
            return Response(
                headers={**headers, "Content-Length": str(file_size)},
                media_type=content_type,
            )
        return FileResponse(str(upload_path), media_type=content_type, headers=headers)

    unit, _, byte_range = range_header.partition("=")
    if unit.strip().lower() != "bytes" or "-" not in byte_range:
        return Response(
            status_code=416,
            headers={"Content-Range": f"bytes */{file_size}"},
        )

    start_text, end_text = byte_range.split("-", 1)
    try:
        if start_text:
            start = int(start_text)
            end = int(end_text) if end_text else file_size - 1
        else:
            suffix_length = int(end_text)
            start = max(file_size - suffix_length, 0)
            end = file_size - 1
    except ValueError:
        return Response(
            status_code=416,
            headers={"Content-Range": f"bytes */{file_size}"},
        )

    if start >= file_size or end < start:
        return Response(
            status_code=416,
            headers={"Content-Range": f"bytes */{file_size}"},
        )

    end = min(end, file_size - 1)
    chunk_size = end - start + 1
    response_headers = {
        **headers,
        "Content-Range": f"bytes {start}-{end}/{file_size}",
        "Content-Length": str(chunk_size),
    }
    if request.method == "HEAD":
        return Response(
            status_code=206,
            headers=response_headers,
            media_type=content_type,
        )

    def iter_file_range():
        with upload_path.open("rb") as file:
            file.seek(start)
            remaining = chunk_size
            while remaining > 0:
                chunk = file.read(min(1024 * 1024, remaining))
                if not chunk:
                    break
                remaining -= len(chunk)
                yield chunk

    return StreamingResponse(
        iter_file_range(),
        status_code=206,
        media_type=content_type,
        headers=response_headers,
    )


app.mount("/uploads", StaticFiles(directory=str(_uploads_dir)), name="uploads")

# ── Flutter Web static file serving ───────────────────────────────────────────
# Serves the Flutter Web build from build/web/ at the root.
# API routes registered above always take priority — only unmatched paths reach here.
# Build the Flutter app first:
#   flutter build web --dart-define=API_BASE_URL=https://streak-pogo-bonded.ngrok-free.dev
_flutter_build = Path(__file__).parent.parent.parent / "build" / "web"


@app.get("/", include_in_schema=False)
@app.get("/{full_path:path}", include_in_schema=False)
async def serve_flutter(full_path: str = ""):
    if not _flutter_build.exists():
        return {"status": "ok", "app": settings.app_name, "note": "No Flutter build found. Run: flutter build web"}
    candidate = _flutter_build / full_path
    if candidate.is_file():
        return FileResponse(str(candidate))
    # For all Flutter client-side routes return index.html (SPA behaviour)
    return FileResponse(str(_flutter_build / "index.html"))
