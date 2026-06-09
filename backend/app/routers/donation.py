import hashlib
import hmac as hmac_lib
import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..dependencies import admin_only
from ..models.donation import Donation, DonationStatus
from ..models.user import User
from ..schemas.donation import DonationCreate, DonationResponse, DonationVerify

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/donations", tags=["Donations"])


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
            detail="razorpay package is not installed. Run: pip install razorpay",
        )


@router.post("", status_code=201, summary="Initiate a donation and create Razorpay order")
def create_donation(
    payload: DonationCreate,
    db: Session = Depends(get_db),
):
    client = _razorpay_client()

    order_data = {
        "amount":   payload.amount,
        "currency": payload.currency,
        "payment_capture": 1,
        "notes": {
            "donor_name":  payload.donor_name,
            "donor_email": payload.donor_email or "",
        },
    }
    rz_order = client.order.create(data=order_data)

    donation = Donation(
        donor_name=payload.donor_name,
        donor_email=payload.donor_email,
        donor_phone=payload.donor_phone,
        amount=payload.amount,
        currency=payload.currency,
        message=payload.message,
        razorpay_order_id=rz_order["id"],
        status=DonationStatus.pending,
    )
    db.add(donation)
    db.commit()
    db.refresh(donation)

    return {
        "donation_id":      donation.id,
        "razorpay_order_id": rz_order["id"],
        "amount":           payload.amount,
        "currency":         payload.currency,
        "key_id":           settings.razorpay_key_id,
    }


@router.post("/verify", response_model=DonationResponse,
             summary="Verify Razorpay payment signature and mark donation complete")
def verify_donation(
    payload: DonationVerify,
    db: Session = Depends(get_db),
):
    donation = db.query(Donation).filter(Donation.id == payload.donation_id).first()
    if not donation:
        raise HTTPException(status_code=404, detail="Donation not found")

    # Verify HMAC signature
    body = f"{payload.razorpay_order_id}|{payload.razorpay_payment_id}"
    expected = hmac_lib.new(
        settings.razorpay_key_secret.encode(),
        body.encode(),
        hashlib.sha256,
    ).hexdigest()
    if not hmac_lib.compare_digest(expected, payload.razorpay_signature):
        donation.status = DonationStatus.failed
        db.commit()
        raise HTTPException(status_code=400, detail="Payment signature verification failed")

    donation.razorpay_payment_id = payload.razorpay_payment_id
    donation.status = DonationStatus.completed
    db.commit()
    db.refresh(donation)
    return donation


@router.get("", response_model=list[DonationResponse],
            summary="List all donations [admin only]")
def list_donations(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    return (
        db.query(Donation)
        .order_by(Donation.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.get("/{donation_id}", response_model=DonationResponse,
            summary="Get a single donation [admin only]")
def get_donation(
    donation_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    d = db.query(Donation).filter(Donation.id == donation_id).first()
    if not d:
        raise HTTPException(status_code=404, detail="Donation not found")
    return d
