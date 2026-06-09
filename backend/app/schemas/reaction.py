from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from ..models.reaction import ReactionType, TargetType


class ToggleReactionRequest(BaseModel):
    target_type:   TargetType
    target_id:     int
    reaction_type: ReactionType


class ReactionCountsResponse(BaseModel):
    target_type:      TargetType
    target_id:        int
    like:             int = 0
    dislike:          int = 0
    upvote:           int = 0
    downvote:         int = 0
    user_reaction:    Optional[ReactionType] = None   # current user's reaction, if any


class ReactionResponse(BaseModel):
    id:            int
    user_id:       int
    target_type:   TargetType
    target_id:     int
    reaction_type: ReactionType
    created_at:    datetime

    class Config:
        from_attributes = True
