from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_role
from app.db.session import get_db
from app.models.models import Fee, User
from app.schemas.schemas import FeeCreate, FeeOut

router = APIRouter(prefix="/fees", tags=["fees"])


@router.post("", response_model=FeeOut, dependencies=[Depends(require_role("admin"))])
def create_fee(
    fee: FeeCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = Fee(school_id=current_user.school_id, **fee.dict())
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


@router.get("", response_model=list[FeeOut], dependencies=[Depends(require_role("admin"))])
def list_fees(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(Fee).filter(Fee.school_id == current_user.school_id).all()
