from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_role
from app.db.session import get_db
from app.models.models import Timetable, User
from app.schemas.schemas import TimetableCreate, TimetableOut

router = APIRouter(prefix="/timetable", tags=["timetable"])


@router.post("", response_model=TimetableOut, dependencies=[Depends(require_role("admin"))])
def create_timetable(
    item: TimetableCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = Timetable(school_id=current_user.school_id, **item.dict())
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


@router.get("", response_model=list[TimetableOut], dependencies=[Depends(require_role("admin", "teacher"))])
def list_timetable(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(Timetable).filter(Timetable.school_id == current_user.school_id)
    if current_user.role == "teacher":
        if current_user.class_id is None:
            return []
        query = query.filter(Timetable.class_id == current_user.class_id)
    return query.all()
