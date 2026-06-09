import hashlib
import hmac as hmac_lib
import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..dependencies import admin_only, get_current_user
from ..models.payment import Payment, PaymentStatus
from ..models.user import User
from ..schemas.payment import CreateOrderRequest, PaymentResponse, VerifyPaymentRequest

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/payments", tags=["Payments"])


def _razorpay_client():
    if not settings.razorpay_key_id or not settings.razorpay_key_secret:
        raise HTTPException(
            status_code=503,
            detail="RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET must be set in .env",
        )
    try:
        import razorpay
        return razorpay.Client(
            auth=(settings.razorpay_key_id, settings.razorpay_key_secret)
        )
    except ImportError:
        raise HTTPException(
            status_code=503,
            detail="razorpay package not installed. Run: pip install razorpay",
        )


@router.post("/order", response_model=dict,
             summary="Create a Razorpay order for a payment")
def create_order(
    payload: CreateOrderRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    client = _razorpay_client()

    notes = payload.notes or {}
    notes["purpose"] = payload.purpose.value
    if payload.reference_id:
        notes["reference_id"] = str(payload.reference_id)

    rz_order = client.order.create(data={
        "amount":          payload.amount,
        "currency":        payload.currency,
        "payment_capture": 1,
        "notes":           notes,
    })

    payment = Payment(
        user_id=current_user.id,
        amount=payload.amount,
        currency=payload.currency,
        purpose=payload.purpose,
        reference_id=payload.reference_id,
        razorpay_order_id=rz_order["id"],
        status=PaymentStatus.created,
    )
    db.add(payment)
    db.commit()
    db.refresh(payment)

    return {
        "payment_id":       payment.id,
        "razorpay_order_id": rz_order["id"],
        "amount":           payload.amount,
        "currency":         payload.currency,
        "key_id":           settings.razorpay_key_id,
    }


@router.post("/verify", response_model=PaymentResponse,
             summary="Verify Razorpay payment and mark as captured")
def verify_payment(
    payload: VerifyPaymentRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payment = db.query(Payment).filter(Payment.id == payload.payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment record not found")
    if payment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your payment")

    body = f"{payload.razorpay_order_id}|{payload.razorpay_payment_id}"
    expected = hmac_lib.new(
        settings.razorpay_key_secret.encode(),
        body.encode(),
        hashlib.sha256,
    ).hexdigest()

    if not hmac_lib.compare_digest(expected, payload.razorpay_signature):
        payment.status = PaymentStatus.failed
        db.commit()
        raise HTTPException(status_code=400, detail="Payment signature verification failed")

    payment.razorpay_payment_id = payload.razorpay_payment_id
    payment.razorpay_signature  = payload.razorpay_signature
    payment.status              = PaymentStatus.captured
    db.commit()
    db.refresh(payment)
    return payment


@router.get("/my", response_model=list[PaymentResponse],
            summary="List the current user's payments")
def my_payments(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return (
        db.query(Payment)
        .filter(Payment.user_id == current_user.id)
        .order_by(Payment.created_at.desc())
        .all()
    )


@router.get("", response_model=list[PaymentResponse],
            summary="List all payments [admin only]")
def list_payments(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    return (
        db.query(Payment)
        .order_by(Payment.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
