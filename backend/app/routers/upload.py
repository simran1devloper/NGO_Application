import uuid
from pathlib import Path
from typing import List

from fastapi import APIRouter, Depends, HTTPException, UploadFile

from ..dependencies import admin_only, content_creator_or_above
from ..models.user import User

router = APIRouter(tags=["Upload"])

_UPLOADS_DIR = Path(__file__).parent.parent.parent / "uploads"
_UPLOADS_DIR.mkdir(exist_ok=True)

_ALLOWED_EXTENSIONS = {
    ".pdf", ".png", ".jpg", ".jpeg", ".gif", ".webp",
    ".mp4", ".mov", ".avi", ".mkv", ".webm",
    ".txt", ".docx", ".zip",
}


def _save_file(file: UploadFile, content: bytes) -> dict:
    original = Path(file.filename or "upload")
    ext = original.suffix.lower()
    if ext not in _ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"File type '{ext}' not allowed.")
    filename = f"{uuid.uuid4()}{ext}"
    dest = _UPLOADS_DIR / filename
    dest.write_bytes(content)
    return {"url": f"/uploads/{filename}", "original_name": original.name}


@router.post(
    "/upload",
    summary="Upload a single file [content_creator, mentor, admin, super_admin]",
)
async def upload_file(
    file: UploadFile,
    _: User = Depends(content_creator_or_above),
):
    return _save_file(file, await file.read())


@router.post(
    "/upload/bulk",
    summary="Upload multiple files at once [content_creator, mentor, admin, super_admin]",
)
async def bulk_upload_files(
    files: List[UploadFile],
    _: User = Depends(content_creator_or_above),
):
    if not files:
        raise HTTPException(status_code=400, detail="No files provided.")
    if len(files) > 20:
        raise HTTPException(status_code=400, detail="Maximum 20 files per request.")

    results = []
    errors  = []
    for f in files:
        try:
            content = await f.read()
            results.append(_save_file(f, content))
        except HTTPException as exc:
            errors.append({"file": f.filename, "error": exc.detail})

    return {"uploaded": results, "errors": errors}


@router.delete(
    "/upload/bulk",
    summary="Delete multiple uploaded files by filename [admin only]",
)
async def bulk_delete_files(
    filenames: List[str],
    _: User = Depends(admin_only),
):
    deleted = []
    not_found = []
    for name in filenames:
        # Prevent path traversal
        safe_name = Path(name).name
        target = _UPLOADS_DIR / safe_name
        if target.is_file() and target.parent == _UPLOADS_DIR:
            target.unlink()
            deleted.append(safe_name)
        else:
            not_found.append(safe_name)
    return {"deleted": deleted, "not_found": not_found}
