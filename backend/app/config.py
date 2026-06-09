import os
from pathlib import Path

from dotenv import load_dotenv

# Load .env from the backend root (one directory above this file)
load_dotenv(Path(__file__).parent.parent / ".env")


class Settings:
    app_name: str = "CareSkill API"
    version: str = "1.0.0"
    debug: bool = True
    database_url: str = "sqlite:///./careskill.db"

    # XP thresholds per level  (level = xp // xp_per_level + 1)
    xp_per_level: int = 500

    # JWT — set SECRET_KEY env var in production; never use the default in prod
    secret_key: str = os.getenv("SECRET_KEY", "careskill-dev-secret-CHANGE-IN-PRODUCTION")
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60   # 1 hour for dev convenience
    refresh_token_expire_days: int = 7

    # Google Calendar / Meet — set these env vars to enable calendar sync
    google_client_id: str = os.getenv("GOOGLE_CLIENT_ID", "")
    google_client_secret: str = os.getenv("GOOGLE_CLIENT_SECRET", "")
    # GOOGLE_REDIRECT_URI can be overridden in .env with your ngrok URL, e.g.
    # GOOGLE_REDIRECT_URI=https://xxxx.ngrok-free.app/auth/google/callback
    google_redirect_uri: str = os.getenv(
        "GOOGLE_REDIRECT_URI", "http://localhost:8000/auth/google/callback"
    )
    # Public base URL — used to build absolute links (e.g. OAuth callbacks via ngrok).
    # Set PUBLIC_URL=https://xxxx.ngrok-free.app in .env when tunnelling.
    public_url: str = os.getenv("PUBLIC_URL", "http://localhost:8000")

    # Auth0 — set AUTH0_DOMAIN and AUTH0_CLIENT_ID in .env
    # Domain:    your Auth0 tenant, e.g. dev-abc123.us.auth0.com
    # Client ID: the Client ID of your Auth0 Native application
    auth0_domain: str = os.getenv("AUTH0_DOMAIN", "")
    auth0_client_id: str = os.getenv("AUTH0_CLIENT_ID", "")

    # Google reCAPTCHA v3 — set RECAPTCHA_SECRET_KEY in .env
    # Get from https://www.google.com/recaptcha/admin
    recaptcha_secret_key: str = os.getenv("RECAPTCHA_SECRET_KEY", "")
    recaptcha_score_threshold: float = 0.5  # 0.0 (bot) to 1.0 (human)

    # Razorpay — set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET in .env
    razorpay_key_id: str = os.getenv("RAZORPAY_KEY_ID", "")
    razorpay_key_secret: str = os.getenv("RAZORPAY_KEY_SECRET", "")


settings = Settings()
