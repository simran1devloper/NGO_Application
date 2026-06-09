from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class CommentCreate(BaseModel):
    post_id:   int
    parent_id: Optional[int] = None
    body:      str


class CommentUpdate(BaseModel):
    body: str


class CommentUserSnippet(BaseModel):
    id:   int
    name: str

    class Config:
        from_attributes = True


class CommentResponse(BaseModel):
    id:         int
    post_id:    int
    user_id:    int
    parent_id:  Optional[int]
    body:       str
    is_edited:  bool
    is_deleted: bool
    # moderation transparency — mediator identity is never included
    is_hidden:        bool = False
    moderation_label: Optional[str] = None   # e.g. "Removed by the moderation team"
    created_at: datetime
    updated_at: datetime
    user:       Optional[CommentUserSnippet] = None
    reply_count: int = 0

    class Config:
        from_attributes = True


class CommentWithRepliesResponse(CommentResponse):
    replies: list[CommentResponse] = []
