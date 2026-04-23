from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

from app.api.deps import get_current_user, require_role
from app.api.v1.common import (
    admin_require_user,
    class_to_out,
    generate_temp_password,
    generate_username,
    require_class,
    require_teacher,
    user_delete_blockers,
)
from app.core.security import hash_password
from app.db.session import get_db
from app.models.models import Assignment, Attendance, Class, Mark, Timetable, User
from app.schemas.schemas import (
    AdminCreateUserIn,
    AdminCreateUserOut,
    AdminDeleteUserOut,
    AdminResetPasswordOut,
    AdminTransferUserDataIn,
    AdminTransferUserDataOut,
    AdminUpdateUserIn,
    ClassCreate,
    ClassOut,
    ClassUpdate,
    StudentCreate,
    UserClassAssignmentIn,
    UserClassAssignmentOut,
    UserOut,
)

admin_router = APIRouter(prefix="/admin", tags=["admin"])
router = APIRouter(tags=["admin"])


@admin_router.post("/users", response_model=AdminCreateUserOut, dependencies=[Depends(require_role("admin"))])
def admin_create_user(
    payload: AdminCreateUserIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.role not in ("student", "teacher"):
        raise HTTPException(status_code=400, detail="Invalid role")

    if payload.role == "student" and not payload.class_id:
        raise HTTPException(status_code=400, detail="class_id required for student")

    if payload.class_id is not None:
        cls = db.query(Class).filter(
            Class.id == payload.class_id,
            Class.school_id == current_user.school_id,
        ).first()
        if not cls:
            raise HTTPException(status_code=404, detail="Class not found")

    if db.query(User).filter(User.email == payload.email).first():
        raise HTTPException(status_code=409, detail="Email already exists")

    username = generate_username(payload.full_name, current_user.school_id)
    temp_password = generate_temp_password()
    assigned_class_id = payload.class_id if payload.role in ("student", "teacher") else None

    user = User(
        school_id=current_user.school_id,
        email=payload.email,
        full_name=payload.full_name,
        username=username,
        password_hash=hash_password(temp_password),
        role=payload.role,
        must_change_password=True,
        class_id=assigned_class_id,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return AdminCreateUserOut(
        id=user.id,
        school_id=user.school_id,
        role=user.role,
        full_name=user.full_name,
        email=user.email,
        username=user.username or username,
        temporary_password=temp_password,
        must_change_password=True,
    )


@admin_router.get("/users", response_model=list[UserOut], dependencies=[Depends(require_role("admin"))])
def admin_list_users(
    role: str | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(User).filter(User.school_id == current_user.school_id)
    if role:
        query = query.filter(User.role == role)
    return query.order_by(User.created_at.desc()).all()


@admin_router.post(
    "/users/{user_id}/reset-password",
    response_model=AdminResetPasswordOut,
    dependencies=[Depends(require_role("admin"))],
)
def admin_reset_password(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = admin_require_user(db, current_user.school_id, user_id)

    temp_password = generate_temp_password()
    user.password_hash = hash_password(temp_password)
    user.must_change_password = True
    db.commit()

    return AdminResetPasswordOut(
        user_id=user.id,
        temporary_password=temp_password,
        must_change_password=True,
    )


@admin_router.put("/users/{user_id}", response_model=UserOut, dependencies=[Depends(require_role("admin"))])
def admin_update_user(
    user_id: int,
    payload: AdminUpdateUserIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = admin_require_user(db, current_user.school_id, user_id)
    if not payload.full_name.strip():
        raise HTTPException(status_code=400, detail="Full name cannot be empty")
    if user.role == "admin" and payload.is_active is False:
        raise HTTPException(status_code=400, detail="Admin users cannot be deactivated")
    existing = db.query(User).filter(
        User.email == payload.email,
        User.id != user.id,
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Email already exists")

    next_class_id = payload.class_id if user.role in ("student", "teacher") else None
    if user.role == "student" and next_class_id is None:
        raise HTTPException(status_code=400, detail="Students must remain assigned to a class")
    if next_class_id is not None:
        require_class(db, current_user.school_id, next_class_id)

    user.full_name = payload.full_name.strip()
    user.email = payload.email
    user.is_active = payload.is_active
    user.class_id = next_class_id
    db.commit()
    db.refresh(user)
    return user


@admin_router.post(
    "/users/{user_id}/transfer-data",
    response_model=AdminTransferUserDataOut,
    dependencies=[Depends(require_role("admin"))],
)
def admin_transfer_user_data(
    user_id: int,
    payload: AdminTransferUserDataIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    source = admin_require_user(db, current_user.school_id, user_id)
    target = admin_require_user(db, current_user.school_id, payload.target_user_id)
    if source.id == target.id:
        raise HTTPException(status_code=400, detail="Choose a different target user")
    if source.role != "teacher" or target.role != "teacher":
        raise HTTPException(status_code=400, detail="Only teacher data can be transferred")

    transferred_classes = db.query(Class).filter(
        Class.school_id == current_user.school_id,
        Class.class_teacher_id == source.id,
    ).update({Class.class_teacher_id: target.id}, synchronize_session=False)
    transferred_assignments = db.query(Assignment).filter(
        Assignment.school_id == current_user.school_id,
        Assignment.teacher_id == source.id,
    ).update({Assignment.teacher_id: target.id}, synchronize_session=False)
    transferred_marks = db.query(Mark).filter(
        Mark.school_id == current_user.school_id,
        Mark.teacher_id == source.id,
    ).update({Mark.teacher_id: target.id}, synchronize_session=False)
    db.commit()
    return AdminTransferUserDataOut(
        source_user_id=source.id,
        target_user_id=target.id,
        transferred_classes=transferred_classes,
        transferred_assignments=transferred_assignments,
        transferred_marks=transferred_marks,
    )


@admin_router.delete(
    "/users/{user_id}",
    response_model=AdminDeleteUserOut,
    dependencies=[Depends(require_role("admin"))],
)
def admin_delete_user(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = admin_require_user(db, current_user.school_id, user_id)
    if user.role == "admin":
        raise HTTPException(status_code=400, detail="Admin users cannot be deleted")
    blockers = user_delete_blockers(db, user)
    if blockers:
        joined = ", ".join(blockers)
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete user with existing {joined}. Transfer or deactivate the user instead.",
        )
    db.delete(user)
    db.commit()
    return AdminDeleteUserOut(deleted=True, user_id=user_id)


@admin_router.put(
    "/users/{user_id}/class-assignment",
    response_model=UserClassAssignmentOut,
    dependencies=[Depends(require_role("admin"))],
)
def admin_assign_user_class(
    user_id: int,
    payload: UserClassAssignmentIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(
        User.id == user_id,
        User.school_id == current_user.school_id,
    ).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role not in ("student", "teacher"):
        raise HTTPException(status_code=400, detail="Only students and teachers can be assigned to classes")

    if payload.class_id is not None:
        require_class(db, current_user.school_id, payload.class_id)

    user.class_id = payload.class_id
    db.commit()
    db.refresh(user)
    return UserClassAssignmentOut(user_id=user.id, class_id=user.class_id, role=user.role)


@router.post("/students", response_model=UserOut, dependencies=[Depends(require_role("admin", "teacher"))])
def create_student(student_in: StudentCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == student_in.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    user = User(
        school_id=student_in.school_id,
        email=student_in.email,
        full_name=student_in.full_name,
        password_hash=hash_password(student_in.password),
        role="student",
        class_id=student_in.class_id,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.get("/students", response_model=list[UserOut], dependencies=[Depends(require_role("admin", "teacher"))])
def list_students(
    class_id: int | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
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
            return []
        query = query.filter(User.class_id == teacher_class_id)
    if class_id is not None:
        query = query.filter(User.class_id == class_id)
    return query.all()


@router.get("/dashboard", dependencies=[Depends(require_role("admin"))])
def dashboard(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    school_id = current_user.school_id
    attendance_count = db.query(Attendance).filter(Attendance.school_id == school_id).count()
    class_count = db.query(Timetable).filter(Timetable.school_id == school_id).count()
    return {"attendance_records": attendance_count, "timetable_entries": class_count}


@router.post("/classes", response_model=ClassOut, dependencies=[Depends(require_role("admin"))])
def create_class(
    data: ClassCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    class_teacher_id = None
    if data.class_teacher_id is not None:
        teacher = require_teacher(db, current_user.school_id, data.class_teacher_id)
        class_teacher_id = teacher.id
    record = Class(
        school_id=current_user.school_id,
        name=data.name,
        class_teacher_id=class_teacher_id,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    if class_teacher_id is not None:
        teacher = require_teacher(db, current_user.school_id, class_teacher_id)
        teacher.class_id = record.id
        db.commit()
        db.refresh(record)
    return class_to_out(db, record)


@router.get("/classes", response_model=list[ClassOut], dependencies=[Depends(require_role("admin", "teacher", "student"))])
def list_classes(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    classes = (
        db.query(Class)
        .options(joinedload(Class.class_teacher))
        .filter(Class.school_id == current_user.school_id)
        .order_by(Class.name.asc())
        .all()
    )
    return [class_to_out(db, klass) for klass in classes]


@router.put("/classes/{class_id}", response_model=ClassOut, dependencies=[Depends(require_role("admin"))])
def update_class(
    class_id: int,
    data: ClassUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = db.query(Class).filter(
        Class.id == class_id,
        Class.school_id == current_user.school_id,
    ).first()
    if not record:
        raise HTTPException(status_code=404, detail="Not found")
    if data.name is not None and not data.name.strip():
        raise HTTPException(status_code=400, detail="Class name cannot be empty")
    if data.name is not None:
        record.name = data.name.strip()
    if data.class_teacher_id is not None:
        teacher = require_teacher(db, current_user.school_id, data.class_teacher_id)
        record.class_teacher_id = teacher.id
        teacher.class_id = record.id
    else:
        record.class_teacher_id = None
    db.commit()
    db.refresh(record)
    return class_to_out(db, record)


@router.delete("/classes/{class_id}", dependencies=[Depends(require_role("admin"))])
def delete_class(
    class_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = db.query(Class).filter(
        Class.id == class_id,
        Class.school_id == current_user.school_id,
    ).first()
    if not record:
        raise HTTPException(status_code=404, detail="Not found")
    has_users = db.query(User).filter(
        User.school_id == current_user.school_id,
        User.class_id == class_id,
    ).first()
    if has_users:
        raise HTTPException(status_code=400, detail="Cannot delete class with assigned users")
    has_timetable = db.query(Timetable).filter(
        Timetable.school_id == current_user.school_id,
        Timetable.class_id == class_id,
    ).first()
    if has_timetable:
        raise HTTPException(status_code=400, detail="Cannot delete class with timetable entries")
    has_attendance = db.query(Attendance).filter(
        Attendance.school_id == current_user.school_id,
        Attendance.class_id == class_id,
    ).first()
    if has_attendance:
        raise HTTPException(status_code=400, detail="Cannot delete class with attendance records")
    has_assignments = db.query(Assignment).filter(
        Assignment.school_id == current_user.school_id,
        Assignment.class_id == class_id,
    ).first()
    if has_assignments:
        raise HTTPException(status_code=400, detail="Cannot delete class with assignments")
    db.delete(record)
    db.commit()
    return {"deleted": True}
