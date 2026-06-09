import enum

from sqlalchemy import Column, DateTime, Enum as SAEnum, ForeignKey, Integer, String, func
from sqlalchemy.orm import relationship

from ..database import Base


class DonationStatus(str, enum.Enum):
    pending   = "pending"
    completed = "completed"
    failed    = "failed"
    refunded  = "refunded"


class Donation(Base):
    __tablename__ = "donations"

    id              = Column(Integer, primary_key=True, index=True)
    donor_name      = Column(String, nullable=False)
    donor_email     = Column(String, nullable=True)
    donor_phone     = Column(String, nullable=True)
    amount          = Column(Integer, nullable=False)   # paise (1 INR = 100 paise)
    currency        = Column(String, default="INR", nullable=False)
    message         = Column(String, nullable=True)
    status          = Column(SAEnum(DonationStatus), default=DonationStatus.pending, nullable=False)
    razorpay_order_id   = Column(String, nullable=True, index=True)
    razorpay_payment_id = Column(String, nullable=True)
    user_id         = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at      = Column(DateTime, server_default=func.now())
    updated_at      = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User")
