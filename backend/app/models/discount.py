import enum

from sqlalchemy import Boolean, Column, DateTime, Enum as SAEnum, Integer, String, func

from ..database import Base


class DiscountType(str, enum.Enum):
    percentage = "percentage"   # e.g. 20 = 20% off
    fixed      = "fixed"        # e.g. 200 = ₹2 off (paise)


class DiscountCode(Base):
    __tablename__ = "discount_codes"

    id              = Column(Integer, primary_key=True, index=True)
    code            = Column(String, unique=True, nullable=False, index=True)
    description     = Column(String, nullable=True)
    discount_type   = Column(SAEnum(DiscountType), default=DiscountType.percentage, nullable=False)
    discount_value  = Column(Integer, nullable=False)   # % or paise
    max_uses        = Column(Integer, nullable=True)     # null = unlimited
    used_count      = Column(Integer, default=0, nullable=False)
    min_amount      = Column(Integer, default=0, nullable=False)  # minimum order paise
    is_active       = Column(Boolean, default=True, nullable=False)
    expires_at      = Column(DateTime, nullable=True)
    created_at      = Column(DateTime, server_default=func.now())
