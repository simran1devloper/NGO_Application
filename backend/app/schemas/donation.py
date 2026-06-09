from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from ..models.donation import DonationStatus


class DonationCreate(BaseModel):
    donor_name:  str
    donor_email: Optional[str] = None
    donor_phone: Optional[str] = None
    amount:      int            # paise (100 = ₹1)
    currency:    str = "INR"
    message:     Optional[str] = None


class DonationVerify(BaseModel):
    donation_id:        int
    razorpay_order_id:  str
    razorpay_payment_id: str
    razorpay_signature: str


class DonationResponse(BaseModel):
    id:                 int
    donor_name:         str
    donor_email:        Optional[str]
    donor_phone:        Optional[str]
    amount:             int
    currency:           str
    message:            Optional[str]
    status:             DonationStatus
    razorpay_order_id:  Optional[str]
    razorpay_payment_id: Optional[str]
    user_id:            Optional[int]
    created_at:         datetime

    class Config:
        from_attributes = True
