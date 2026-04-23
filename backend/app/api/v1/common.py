import secrets
import string

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.models import (
    Assignment,
    AssignmentSubmission,
    Attendance,
    Class,
    Fee,
    Mark,
    NoticeRead,
    User,
)
from app.schemas.schemas import ClassOut

ASSIGNMENT_STATUS = {"pending", "submitted", "late", "missing"}
ASSESSMENT_TYPES = {"test", "exam"}
PERIOD_SLOTS = {
    1: ("08:00", "08:45"),
    2: ("08:50", "09:35"),
    3: ("09:45", "10:30"),
    4: ("10:40", "11:25"),
    5: ("11:35", "12:20"),
    6: ("13:00", "13:45"),
}


def require_class(db: Session, school_id: int, class_id: int) -> Class:
    klass = db.query(Class).filter(
        Class.id == class_id,
        Class.school_id == school_id,
    ).first()
    if not klass:
        raise HTTPException(status_code=400, detail="Invalid class_id")
    return klass


def require_student(
    db: Session,
    school_id: int,
    student_id: int,
    class_id: int | None = None,
) -> User:
    student = db.query(User).filter(
        User.id == student_id,
        User.school_id == school_id,
        User.role == "student",
    ).first()
    if not student:
        raise HTTPException(status_code=400, detail="Invalid student_id")
    if class_id is not None and student.class_id and student.class_id != class_id:
        raise HTTPException(status_code=400, detail="Student not in class")
    return student


def require_teacher(db: Session, school_id: int, teacher_id: int) -> User:
    teacher = db.query(User).filter(
        User.id == teacher_id,
        User.school_id == school_id,
        User.role == "teacher",
    ).first()
    if not teacher:
        raise HTTPException(status_code=400, detail="Invalid teacher_id")
    return teacher


def class_to_out(db: Session, klass: Class) -> ClassOut:
    teacher = getattr(klass, "class_teacher", None)
    class_teacher_name = teacher.full_name if teacher else None
    return ClassOut(
        id=klass.id,
        school_id=klass.school_id,
        name=klass.name,
        class_teacher_id=klass.class_teacher_id,
        class_teacher_name=class_teacher_name,
    )


def teacher_visible_students_query(current_user: User, db: Session):
    query = db.query(User).filter(
        User.school_id == current_user.school_id,
        User.role == "student",
    )
    if current_user.role == "teacher":
        teacher_class_id = current_user.class_id
        if teacher_class_id is None:
            klass = db.query(Class).filter(
                Class.school_id == current_user.school_id,
                Class.class_teacher_id == current_user.id,
            ).first()
            teacher_class_id = klass.id if klass else None
        if teacher_class_id is None:
            query = query.filter(User.id == -1)
        else:
            query = query.filter(User.class_id == teacher_class_id)
    return query


def generate_username(full_name: str, school_id: int) -> str:
    base = "".join(c for c in full_name.lower() if c.isalnum())
    suffix = secrets.token_hex(2)
    return f"{base}{school_id}{suffix}"


def generate_temp_password(length: int = 10) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def admin_require_user(db: Session, school_id: int, user_id: int) -> User:
    user = db.query(User).filter(
        User.id == user_id,
        User.school_id == school_id,
    ).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


def user_delete_blockers(db: Session, user: User) -> list[str]:
    blockers: list[str] = []
    if user.role == "teacher":
        if db.query(Class).filter(
            Class.school_id == user.school_id,
            Class.class_teacher_id == user.id,
        ).first():
            blockers.append("class teacher assignments")
        if db.query(Assignment).filter(
            Assignment.school_id == user.school_id,
            Assignment.teacher_id == user.id,
        ).first():
            blockers.append("assignments")
        if db.query(Mark).filter(
            Mark.school_id == user.school_id,
            Mark.teacher_id == user.id,
        ).first():
            blockers.append("marks")
    if user.role == "student":
        if db.query(Attendance).filter(
            Attendance.school_id == user.school_id,
            Attendance.student_id == user.id,
        ).first():
            blockers.append("attendance records")
        if db.query(Fee).filter(
            Fee.school_id == user.school_id,
            Fee.student_id == user.id,
        ).first():
            blockers.append("fee records")
        if db.query(Mark).filter(
            Mark.school_id == user.school_id,
            Mark.student_id == user.id,
        ).first():
            blockers.append("marks")
        if db.query(AssignmentSubmission).filter(
            AssignmentSubmission.student_id == user.id,
        ).first():
            blockers.append("assignment submissions")
        if db.query(NoticeRead).filter(
            NoticeRead.student_id == user.id,
        ).first():
            blockers.append("notice reads")
    return blockers
