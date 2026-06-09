from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import admin_only
from ..models.discount import DiscountCode, DiscountType
from ..models.user import User
from ..schemas.discount import (
    DiscountCodeCreate,
    DiscountCodeResponse,
    DiscountCodeUpdate,
    ValidateCodeRequest,
    ValidateCodeResponse,
)

router = APIRouter(prefix="/discounts", tags=["Discounts"])


def _calc_discount(code: DiscountCode, amount: int) -> int:
    """Returns the discount amount in paise."""
    if code.discount_type == DiscountType.percentage:
        return int(amount * code.discount_value / 100)
    return min(code.discount_value, amount)  # fixed, can't exceed order amount


@router.post("/validate", response_model=ValidateCodeResponse,
             summary="Validate a discount code against an order amount (public)")
def validate_code(
    payload: ValidateCodeRequest,
    db: Session = Depends(get_db),
):
    code = db.query(DiscountCode).filter(
        DiscountCode.code == payload.code.upper().strip()
    ).first()

    if not code or not code.is_active:
        return ValidateCodeResponse(valid=False, message="Invalid or inactive discount code.")

    if code.expires_at and datetime.now(timezone.utc) > code.expires_at.replace(tzinfo=timezone.utc):
        return ValidateCodeResponse(valid=False, message="This discount code has expired.")

    if code.max_uses is not None and code.used_count >= code.max_uses:
        return ValidateCodeResponse(valid=False, message="This discount code has reached its usage limit.")

    if payload.amount < code.min_amount:
        return ValidateCodeResponse(
            valid=False,
            message=f"Minimum order amount of ₹{code.min_amount // 100} required for this code.",
        )

    discount = _calc_discount(code, payload.amount)
    return ValidateCodeResponse(
        valid=True,
        discount_type=code.discount_type,
        discount_value=code.discount_value,
        discount_amount=discount,
        final_amount=max(0, payload.amount - discount),
        message="Code applied successfully.",
    )


@router.post("/apply", summary="Apply a discount code (increments usage counter)")
def apply_code(
    payload: ValidateCodeRequest,
    db: Session = Depends(get_db),
):
    """Call after a successful payment to record usage."""
    code = db.query(DiscountCode).filter(
        DiscountCode.code == payload.code.upper().strip()
    ).first()
    if not code:
        raise HTTPException(status_code=404, detail="Discount code not found")

    code.used_count += 1
    db.commit()
    discount = _calc_discount(code, payload.amount)
    return {
        "code":            code.code,
        "discount_amount": discount,
        "final_amount":    max(0, payload.amount - discount),
    }


# ── Admin management ──────────────────────────────────────────────────────────

@router.post("", status_code=201, response_model=DiscountCodeResponse,
             summary="Create a discount code [admin only]")
def create_code(
    payload: DiscountCodeCreate,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    existing = db.query(DiscountCode).filter(
        DiscountCode.code == payload.code.upper().strip()
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Discount code already exists")

    code = DiscountCode(
        code=payload.code.upper().strip(),
        description=payload.description,
        discount_type=payload.discount_type,
        discount_value=payload.discount_value,
        max_uses=payload.max_uses,
        min_amount=payload.min_amount,
        expires_at=payload.expires_at,
    )
    db.add(code)
    db.commit()
    db.refresh(code)
    return code


@router.get("", response_model=list[DiscountCodeResponse],
            summary="List all discount codes [admin only]")
def list_codes(
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    return db.query(DiscountCode).order_by(DiscountCode.created_at.desc()).all()


@router.patch("/{code_id}", response_model=DiscountCodeResponse,
              summary="Update a discount code [admin only]")
def update_code(
    code_id: int,
    payload: DiscountCodeUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    code = db.query(DiscountCode).filter(DiscountCode.id == code_id).first()
    if not code:
        raise HTTPException(status_code=404, detail="Discount code not found")

    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(code, field, value)
    db.commit()
    db.refresh(code)
    return code


@router.delete("/{code_id}", status_code=204,
               summary="Delete a discount code [admin only]")
def delete_code(
    code_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    code = db.query(DiscountCode).filter(DiscountCode.id == code_id).first()
    if not code:
        raise HTTPException(status_code=404, detail="Discount code not found")
    db.delete(code)
    db.commit()
