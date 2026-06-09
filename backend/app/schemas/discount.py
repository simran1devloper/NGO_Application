from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from ..models.discount import DiscountType


class DiscountCodeCreate(BaseModel):
    code:           str
    description:    Optional[str] = None
    discount_type:  DiscountType = DiscountType.percentage
    discount_value: int = Field(..., gt=0)
    max_uses:       Optional[int] = None
    min_amount:     int = 0
    expires_at:     Optional[datetime] = None


class DiscountCodeUpdate(BaseModel):
    description:    Optional[str] = None
    discount_value: Optional[int] = None
    max_uses:       Optional[int] = None
    min_amount:     Optional[int] = None
    is_active:      Optional[bool] = None
    expires_at:     Optional[datetime] = None


class ValidateCodeRequest(BaseModel):
    code:   str
    amount: int   # paise — the order total before discount


class ValidateCodeResponse(BaseModel):
    valid:          bool
    discount_type:  Optional[DiscountType] = None
    discount_value: Optional[int] = None
    discount_amount: Optional[int] = None    # paise saved
    final_amount:   Optional[int] = None     # paise after discount
    message:        str


class DiscountCodeResponse(BaseModel):
    id:             int
    code:           str
    description:    Optional[str]
    discount_type:  DiscountType
    discount_value: int
    max_uses:       Optional[int]
    used_count:     int
    min_amount:     int
    is_active:      bool
    expires_at:     Optional[datetime]
    created_at:     datetime

    class Config:
        from_attributes = True
