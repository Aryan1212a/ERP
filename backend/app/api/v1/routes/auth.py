import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import create_access_token, hash_password, verify_password
from app.db.session import get_db
from app.models.models import User
from app.schemas.schemas import ChangePasswordIn, ChangePasswordOut, LoginIn, Token, UserCreate, UserOut

profile_router = APIRouter(tags=["auth"])
router = APIRouter(prefix="/auth", tags=["auth"])
logger = logging.getLogger(__name__)


@profile_router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.post("/register", response_model=UserOut)
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == user_in.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    user = User(
        school_id=user_in.school_id,
        email=user_in.email,
        full_name=user_in.full_name,
        password_hash=hash_password(user_in.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=Token)
def login(data: LoginIn, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user or not verify_password(data.password, user.password_hash):
        logger.warning("Login failed for %s", data.email)
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not user.is_active:
        logger.warning("Blocked inactive login for user_id=%s", user.id)
        raise HTTPException(status_code=401, detail="Inactive user")
    token = create_access_token({"sub": user.id, "school_id": user.school_id})
    logger.info("Login succeeded for user_id=%s role=%s", user.id, user.role)
    return Token(
        access_token=token,
        user_id=user.id,
        role=user.role,
        must_change_password=user.must_change_password,
    )


@router.post("/change-password", response_model=ChangePasswordOut)
def change_password(
    payload: ChangePasswordIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not verify_password(payload.old_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Invalid current password")
    current_user.password_hash = hash_password(payload.new_password)
    current_user.must_change_password = False
    db.commit()
    return ChangePasswordOut(status="ok")
