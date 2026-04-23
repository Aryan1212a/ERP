from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_role
from app.api.v1.common import require_class, require_student
from app.db.session import get_db
from app.models.models import Attendance, User
from app.schemas.schemas import AttendanceCreate, AttendanceOut, TeacherAttendanceIn, TeacherAttendanceOut

router = APIRouter(prefix="/attendance", tags=["attendance"])
teacher_router = APIRouter(prefix="/teacher", tags=["attendance"])


@router.post("", response_model=AttendanceOut, dependencies=[Depends(require_role("admin"))])
def create_attendance(
    att: AttendanceCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_class(db, current_user.school_id, att.class_id)
    require_student(db, current_user.school_id, att.student_id, att.class_id)
    record = Attendance(school_id=current_user.school_id, **att.dict())
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


@router.get("", response_model=list[AttendanceOut], dependencies=[Depends(require_role("admin", "teacher"))])
def list_attendance(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(Attendance).filter(Attendance.school_id == current_user.school_id)
    if current_user.role == "teacher":
        if current_user.class_id is None:
            return []
        query = query.filter(Attendance.class_id == current_user.class_id)
    return query.all()


@router.put("/{attendance_id}", response_model=AttendanceOut, dependencies=[Depends(require_role("admin"))])
def update_attendance(
    attendance_id: int,
    att: AttendanceCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = db.query(Attendance).filter(
        Attendance.id == attendance_id,
        Attendance.school_id == current_user.school_id,
    ).first()
    if not record:
        raise HTTPException(status_code=404, detail="Not found")
    require_class(db, current_user.school_id, att.class_id)
    require_student(db, current_user.school_id, att.student_id, att.class_id)
    for key, value in att.dict().items():
        setattr(record, key, value)
    db.commit()
    db.refresh(record)
    return record


@router.delete("/{attendance_id}", dependencies=[Depends(require_role("admin"))])
def delete_attendance(
    attendance_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = db.query(Attendance).filter(
        Attendance.id == attendance_id,
        Attendance.school_id == current_user.school_id,
    ).first()
    if not record:
        raise HTTPException(status_code=404, detail="Not found")
    db.delete(record)
    db.commit()
    return {"deleted": True}


@teacher_router.post("/attendance", response_model=TeacherAttendanceOut, dependencies=[Depends(require_role("teacher"))])
def teacher_mark_attendance(
    payload: TeacherAttendanceIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_class(db, current_user.school_id, payload.class_id)
    for record in payload.records:
        require_student(db, current_user.school_id, record.student_id, payload.class_id)
        existing = db.query(Attendance).filter(
            Attendance.school_id == current_user.school_id,
            Attendance.class_id == payload.class_id,
            Attendance.student_id == record.student_id,
            Attendance.date == payload.date,
        ).first()
        if existing:
            existing.status = record.status
            continue
        db.add(
            Attendance(
                school_id=current_user.school_id,
                class_id=payload.class_id,
                student_id=record.student_id,
                date=payload.date,
                status=record.status,
            )
        )
    db.commit()
    return TeacherAttendanceOut(
        class_id=payload.class_id,
        date=payload.date,
        saved=len(payload.records),
        status="ok",
    )
