import logging

import httpx

from .config import settings

logger = logging.getLogger(__name__)

_VERIFY_URL = "https://www.google.com/recaptcha/api/siteverify"


async def verify_recaptcha(token: str) -> bool:
    """Returns True when the token passes reCAPTCHA v3 verification.

    Returns True without making a network call when RECAPTCHA_SECRET_KEY is
    not configured (dev/test environments where captcha is disabled).
    """
    if not settings.recaptcha_secret_key:
        return True

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.post(
                _VERIFY_URL,
                data={
                    "secret": settings.recaptcha_secret_key,
                    "response": token,
                },
            )
        result = resp.json()
        if not result.get("success"):
            logger.warning("reCAPTCHA failed: %s", result.get("error-codes"))
            return False
        score: float = result.get("score", 0.0)
        if score < settings.recaptcha_score_threshold:
            logger.warning("reCAPTCHA score too low: %.2f", score)
            return False
        return True
    except Exception as exc:
        logger.error("reCAPTCHA verification error: %s", exc)
        # Fail open on network errors so a CAPTCHA outage doesn't lock users out
        return True
