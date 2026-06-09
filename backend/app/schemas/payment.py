from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from ..models.payment import PaymentPurpose, PaymentStatus


class CreateOrderRequest(BaseModel):
    amount:      int           # paise (100 = ₹1)
    currency:    str = "INR"
    purpose:     PaymentPurpose
    reference_id: Optional[int] = None   # course_id / event_id / etc.
    notes:       Optional[dict] = None


class VerifyPaymentRequest(BaseModel):
    payment_id:         int    # internal Payment row id
    razorpay_order_id:  str
    razorpay_payment_id: str
    razorpay_signature: str


class PaymentResponse(BaseModel):
    id:                 int
    user_id:            Optional[int]
    amount:             int
    currency:           str
    purpose:            PaymentPurpose
    reference_id:       Optional[int]
    status:             PaymentStatus
    razorpay_order_id:  Optional[str]
    razorpay_payment_id: Optional[str]
    created_at:         datetime

    class Config:
        from_attributes = True
