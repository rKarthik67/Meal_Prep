"""Authentication.

The Flutter app signs users in with Firebase phone OTP and sends the Firebase ID
token as `Authorization: Bearer <token>`. The backend verifies it and maps the
Firebase UID to a row in `users` (created on first sight).

For local development without a Firebase project, set AUTH_MODE=dev and send
`Bearer dev:<phone>` (e.g. `dev:+919876543210`).
"""

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import get_settings
from .db import get_db
from .models import Role, User

_firebase_app = None


def _verify_firebase(token: str) -> tuple[str, str]:
    global _firebase_app
    import firebase_admin
    from firebase_admin import auth as fb_auth, credentials

    if _firebase_app is None:
        cred_path = get_settings().firebase_credentials
        cred = credentials.Certificate(cred_path) if cred_path else credentials.ApplicationDefault()
        _firebase_app = firebase_admin.initialize_app(cred)
    try:
        decoded = fb_auth.verify_id_token(token, app=_firebase_app)
    except Exception as exc:  # noqa: BLE001 - firebase raises several error types
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid Firebase token") from exc
    return decoded["uid"], decoded.get("phone_number", "")


def _identify(token: str) -> tuple[str, str]:
    settings = get_settings()
    if settings.auth_mode == "dev" and token.startswith("dev:"):
        phone = token[4:].strip()
        if not phone:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Empty dev token")
        return f"dev-{phone}", phone
    if settings.auth_mode == "firebase":
        return _verify_firebase(token)
    raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Unsupported token for current AUTH_MODE")


def current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing bearer token")
    uid, phone = _identify(authorization.split(" ", 1)[1].strip())

    user = db.scalar(select(User).where(User.firebase_uid == uid))
    if user is None:
        user = User(firebase_uid=uid, phone=phone, name="", role=Role.customer)
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


def require_role(*roles: Role):
    def dep(user: User = Depends(current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(status.HTTP_403_FORBIDDEN, f"Requires role: {', '.join(r.value for r in roles)}")
        return user

    return dep
