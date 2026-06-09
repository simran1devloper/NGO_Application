import enum

from sqlalchemy import Column, DateTime, Enum as SAEnum, ForeignKey, Integer, String, func
from sqlalchemy.orm import relationship

from ..database import Base


class PaymentStatus(str, enum.Enum):
    created   = "created"
    captured  = "captured"
    failed    = "failed"
    refunded  = "refunded"


class PaymentPurpose(str, enum.Enum):
    course   = "course"
    donation = "donation"
    event    = "event"


class Payment(Base):
    __tablename__ = "payments"

    id                  = Column(Integer, primary_key=True, index=True)
    user_id             = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    amount              = Column(Integer, nullable=False)     # paise
    currency            = Column(String, default="INR", nullable=False)
    purpose             = Column(SAEnum(PaymentPurpose), nullable=False)
    reference_id        = Column(Integer, nullable=True)      # course_id / donation_id / event_id
    status              = Column(SAEnum(PaymentStatus), default=PaymentStatus.created, nullable=False)
    razorpay_order_id   = Column(String, nullable=True, index=True)
    razorpay_payment_id = Column(String, nullable=True)
    razorpay_signature  = Column(String, nullable=True)
    created_at          = Column(DateTime, server_default=func.now())
    updated_at          = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User")
