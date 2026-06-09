from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import get_current_user
from ..models.reaction import Reaction, ReactionType, TargetType
from ..models.user import User
from ..schemas.reaction import ReactionCountsResponse, ToggleReactionRequest

router = APIRouter(prefix="/reactions", tags=["Reactions"])


def _get_counts(db: Session, target_type: TargetType, target_id: int,
                current_user: User) -> ReactionCountsResponse:
    rows = db.query(Reaction).filter(
        Reaction.target_type == target_type,
        Reaction.target_id   == target_id,
    ).all()

    counts = {rt: 0 for rt in ReactionType}
    user_reaction = None
    for r in rows:
        counts[r.reaction_type] += 1
        if r.user_id == current_user.id:
            user_reaction = r.reaction_type

    return ReactionCountsResponse(
        target_type=target_type,
        target_id=target_id,
        like=counts[ReactionType.like],
        dislike=counts[ReactionType.dislike],
        upvote=counts[ReactionType.upvote],
        downvote=counts[ReactionType.downvote],
        user_reaction=user_reaction,
    )


@router.post("/toggle", response_model=ReactionCountsResponse,
             summary="Toggle a reaction. Same reaction → removed; opposite → updated.")
def toggle_reaction(
    payload: ToggleReactionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    existing = db.query(Reaction).filter(
        Reaction.user_id     == current_user.id,
        Reaction.target_type == payload.target_type,
        Reaction.target_id   == payload.target_id,
    ).first()

    if existing:
        if existing.reaction_type == payload.reaction_type:
            # Same reaction → toggle off
            db.delete(existing)
        else:
            # Different reaction → swap
            existing.reaction_type = payload.reaction_type
    else:
        db.add(Reaction(
            user_id=current_user.id,
            target_type=payload.target_type,
            target_id=payload.target_id,
            reaction_type=payload.reaction_type,
        ))

    db.commit()
    return _get_counts(db, payload.target_type, payload.target_id, current_user)


@router.get("/{target_type}/{target_id}", response_model=ReactionCountsResponse,
            summary="Get reaction counts for a target")
def get_counts(
    target_type: TargetType,
    target_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _get_counts(db, target_type, target_id, current_user)


@router.get("/bulk/{target_type}", response_model=list[ReactionCountsResponse],
            summary="Get reaction counts for multiple target IDs")
def get_bulk_counts(
    target_type: TargetType,
    ids: str,   # comma-separated list of IDs
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        id_list = [int(x) for x in ids.split(",") if x.strip()]
    except ValueError:
        return []

    rows = db.query(Reaction).filter(
        Reaction.target_type == target_type,
        Reaction.target_id.in_(id_list),
    ).all()

    # Aggregate per target_id
    data: dict[int, dict] = {tid: {"like": 0, "dislike": 0, "upvote": 0, "downvote": 0, "user_reaction": None}
                              for tid in id_list}
    for r in rows:
        data[r.target_id][r.reaction_type.value] += 1
        if r.user_id == current_user.id:
            data[r.target_id]["user_reaction"] = r.reaction_type

    return [
        ReactionCountsResponse(
            target_type=target_type,
            target_id=tid,
            **data[tid],
        )
        for tid in id_list
    ]
