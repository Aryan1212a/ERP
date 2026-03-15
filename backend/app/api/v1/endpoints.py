from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
import secrets
import string
from sqlalchemy import select, and_
from datetime import date, timedelta
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.models import (
    User, Attendance, Timetable, Fee, Notice, Class,
    Assignment, AssignmentSubmission, Mark, NoticeRead
)
from app.schemas.schemas import (
    UserCreate, UserOut, LoginIn, Token, StudentCreate,
    ClassCreate, ClassOut,
    AttendanceCreate, AttendanceOut,
    TimetableCreate, TimetableOut,
    FeeCreate, FeeOut,
    NoticeCreate, NoticeOut,
    TeacherSummaryOut, TeacherScheduleOut, ScheduleItemOut,
    StudentInsightsOut, StudentInsightOut,
    TeacherAttendanceIn, TeacherAttendanceOut,
    AssignmentCreateOut,
    TeacherAssignmentsManageOut, TeacherAssignmentManageItemOut, TeacherAssignmentStudentOut,
    TeacherAssignmentStatusIn, TeacherAssignmentStatusOut, TeacherAssignmentOverdueOut,
    MarksIn, MarksOut,
    StudentSummaryOut, StudentTimetableOut,
    StudentAssignmentsOut, StudentAssignmentOut,
    StudentPerformanceOut, StudentPerformanceItemOut,
    StudentNoticesOut, StudentNoticeOut,
    AdminCreateUserIn, AdminCreateUserOut,
    AdminResetPasswordOut,
    ChangePasswordIn, ChangePasswordOut,
)
from app.core.security import hash_password, verify_password, create_access_token
from app.api.deps import get_current_user, require_role

router = APIRouter()
ASSIGNMENT_STATUS = {"pending", "submitted", "late", "missing"}

def _require_class(db: Session, school_id: int, class_id: int) -> Class:
    klass = db.query(Class).filter(
        Class.id == class_id,
        Class.school_id == school_id,
    ).first()
    if not klass:
        raise HTTPException(status_code=400, detail="Invalid class_id")
    return klass

def _require_student(db: Session, school_id: int, student_id: int, class_id: int | None = None) -> User:
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

def _generate_username(full_name: str, school_id: int) -> str:
    base = "".join(c for c in full_name.lower() if c.isalnum())
    suffix = secrets.token_hex(2)
    return f"{base}{school_id}{suffix}"

def _generate_temp_password(length: int = 10) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))

@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user

@router.post("/auth/register", response_model=UserOut)
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

@router.post("/admin/users", response_model=AdminCreateUserOut, dependencies=[Depends(require_role("admin"))])
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

    username = _generate_username(payload.full_name, current_user.school_id)
    temp_password = _generate_temp_password()

    user = User(
        school_id=current_user.school_id,
        email=payload.email,
        full_name=payload.full_name,
        username=username,
        password_hash=hash_password(temp_password),
        role=payload.role,
        must_change_password=True,
        class_id=payload.class_id if payload.role == "student" else None,
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

@router.get("/admin/users", response_model=list[UserOut], dependencies=[Depends(require_role("admin"))])
def admin_list_users(
    role: str | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(User).filter(User.school_id == current_user.school_id)
    if role:
        query = query.filter(User.role == role)
    return query.order_by(User.created_at.desc()).all()

@router.post("/admin/users/{user_id}/reset-password", response_model=AdminResetPasswordOut, dependencies=[Depends(require_role("admin"))])
def admin_reset_password(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(
        User.id == user_id,
        User.school_id == current_user.school_id,
    ).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    temp_password = _generate_temp_password()
    user.password_hash = hash_password(temp_password)
    user.must_change_password = True
    db.commit()

    return AdminResetPasswordOut(
        user_id=user.id,
        temporary_password=temp_password,
        must_change_password=True,
    )

@router.post("/auth/change-password", response_model=ChangePasswordOut)
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
    if class_id is not None:
        query = query.filter(User.class_id == class_id)
    return query.all()

@router.post("/auth/login", response_model=Token)
def login(data: LoginIn, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = create_access_token({"sub": user.id, "school_id": user.school_id})
    return Token(
        access_token=token,
        user_id=user.id,
        role=user.role,
        must_change_password=user.must_change_password,
    )

@router.get("/dashboard")
def dashboard(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    school_id = current_user.school_id
    attendance_count = db.query(Attendance).filter(Attendance.school_id == school_id).count()
    class_count = db.query(Timetable).filter(Timetable.school_id == school_id).count()
    return {"attendance_records": attendance_count, "timetable_entries": class_count}

@router.post("/attendance", response_model=AttendanceOut)
def create_attendance(
    att: AttendanceCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_class(db, current_user.school_id, att.class_id)
    _require_student(db, current_user.school_id, att.student_id, att.class_id)
    record = Attendance(school_id=current_user.school_id, **att.dict())
    db.add(record)
    db.commit()
    db.refresh(record)
    return record

@router.get("/attendance", response_model=list[AttendanceOut])
def list_attendance(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(Attendance).filter(Attendance.school_id == current_user.school_id).all()

@router.put("/attendance/{attendance_id}", response_model=AttendanceOut)
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
    _require_class(db, current_user.school_id, att.class_id)
    _require_student(db, current_user.school_id, att.student_id, att.class_id)
    for k, v in att.dict().items():
        setattr(record, k, v)
    db.commit()
    db.refresh(record)
    return record

@router.delete("/attendance/{attendance_id}")
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

@router.post("/timetable", response_model=TimetableOut)
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

@router.get("/timetable", response_model=list[TimetableOut])
def list_timetable(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(Timetable).filter(Timetable.school_id == current_user.school_id).all()

@router.post("/fees", response_model=FeeOut)
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

@router.get("/fees", response_model=list[FeeOut])
def list_fees(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(Fee).filter(Fee.school_id == current_user.school_id).all()

@router.post("/notices", response_model=NoticeOut)
def create_notice(
    notice: NoticeCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = Notice(school_id=current_user.school_id, **notice.dict())
    db.add(record)
    db.commit()
    db.refresh(record)
    return record

@router.post("/classes", response_model=ClassOut, dependencies=[Depends(require_role("admin", "teacher"))])
def create_class(
    data: ClassCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = Class(school_id=current_user.school_id, name=data.name)
    db.add(record)
    db.commit()
    db.refresh(record)
    return record

@router.get("/classes", response_model=list[ClassOut])
def list_classes(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(Class).filter(Class.school_id == current_user.school_id).all()

@router.put("/classes/{class_id}", response_model=ClassOut, dependencies=[Depends(require_role("admin", "teacher"))])
def update_class(
    class_id: int,
    data: ClassCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = db.query(Class).filter(
        Class.id == class_id,
        Class.school_id == current_user.school_id,
    ).first()
    if not record:
        raise HTTPException(status_code=404, detail="Not found")
    record.name = data.name
    db.commit()
    db.refresh(record)
    return record

@router.delete("/classes/{class_id}", dependencies=[Depends(require_role("admin", "teacher"))])
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
    db.delete(record)
    db.commit()
    return {"deleted": True}

@router.get("/notices", response_model=list[NoticeOut])
def list_notices(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(Notice).filter(Notice.school_id == current_user.school_id).all()

# -------- Teacher Dashboard Endpoints --------

@router.get("/teacher/summary", response_model=TeacherSummaryOut, dependencies=[Depends(require_role("teacher", "admin"))])
def teacher_summary(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    today = date.today()
    weekday = today.weekday()

    today_classes = db.query(Timetable).filter(
        Timetable.school_id == current_user.school_id,
        Timetable.day_of_week == weekday,
    ).count()

    attendance_today = db.query(Attendance.class_id).filter(
        Attendance.school_id == current_user.school_id,
        Attendance.date == today,
    ).distinct().count()

    pending_attendance = max(today_classes - attendance_today, 0)

    teacher_assignments = select(Assignment.id).where(
        Assignment.school_id == current_user.school_id,
        Assignment.teacher_id == current_user.id,
    )
    assignments_to_review = db.query(AssignmentSubmission).filter(
        AssignmentSubmission.assignment_id.in_(teacher_assignments),
        AssignmentSubmission.status == "submitted",
    ).count()

    absent_students = db.query(Attendance.student_id).filter(
        Attendance.school_id == current_user.school_id,
        Attendance.status == "absent",
        Attendance.date >= today - timedelta(days=14),
    ).distinct().count()

    return TeacherSummaryOut(
        teacher_id=current_user.id,
        school_id=current_user.school_id,
        today_classes=today_classes,
        pending_attendance=pending_attendance,
        assignments_to_review=assignments_to_review,
        low_attendance_alerts=absent_students,
    )

@router.get("/teacher/schedule/today", response_model=TeacherScheduleOut, dependencies=[Depends(require_role("teacher", "admin"))])
def teacher_schedule_today(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    today = date.today()
    weekday = today.weekday()
    periods = {
        1: ("08:00", "08:45"),
        2: ("08:50", "09:35"),
        3: ("09:45", "10:30"),
        4: ("10:40", "11:25"),
        5: ("11:35", "12:20"),
        6: ("13:00", "13:45"),
    }

    rows = db.query(Timetable).filter(
        Timetable.school_id == current_user.school_id,
        Timetable.day_of_week == weekday,
    ).order_by(Timetable.period).all()

    schedule = []
    for row in rows:
        start_time, end_time = periods.get(row.period, ("--:--", "--:--"))
        schedule.append(
            ScheduleItemOut(
                period=row.period,
                start_time=start_time,
                end_time=end_time,
                subject=row.subject,
                class_id=row.class_id,
                room=None,
            )
        )

    return TeacherScheduleOut(
        date=today,
        teacher_id=current_user.id,
        schedule=schedule,
    )

@router.get("/teacher/students/insights", response_model=StudentInsightsOut, dependencies=[Depends(require_role("teacher", "admin"))])
def teacher_student_insights(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    today = date.today()
    since = today - timedelta(days=30)

    attendance_rows = db.query(Attendance).filter(
        Attendance.school_id == current_user.school_id,
        Attendance.date >= since,
    ).all()

    totals: dict[int, int] = {}
    presents: dict[int, int] = {}
    for row in attendance_rows:
        totals[row.student_id] = totals.get(row.student_id, 0) + 1
        if row.status == "present":
            presents[row.student_id] = presents.get(row.student_id, 0) + 1

    below_threshold = []
    for student_id, total in totals.items():
        if total < 3:
            continue
        present = presents.get(student_id, 0)
        pct = present / total
        if pct < 0.75:
            student = db.query(User).filter(User.id == student_id).first()
            if student:
                below_threshold.append(
                    StudentInsightOut(
                        student_id=student.id,
                        name=student.full_name,
                        reason=f"Attendance {int(pct * 100)}%",
                    )
                )

    teacher_assignments = select(Assignment.id).where(
        Assignment.school_id == current_user.school_id,
        Assignment.teacher_id == current_user.id,
    )
    missing_rows = db.query(AssignmentSubmission).filter(
        AssignmentSubmission.assignment_id.in_(teacher_assignments),
        AssignmentSubmission.status == "missing",
    ).all()

    missing_students = []
    for row in missing_rows:
        student = db.query(User).filter(User.id == row.student_id).first()
        if student:
            missing_students.append(
                StudentInsightOut(
                    student_id=student.id,
                    name=student.full_name,
                    reason="Missing assignment",
                )
            )

    return StudentInsightsOut(
        below_attendance_threshold=below_threshold,
        missing_assignments=missing_students,
    )

@router.post("/teacher/attendance", response_model=TeacherAttendanceOut, dependencies=[Depends(require_role("teacher", "admin"))])
def teacher_mark_attendance(
    payload: TeacherAttendanceIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_class(db, current_user.school_id, payload.class_id)
    for record in payload.records:
        _require_student(db, current_user.school_id, record.student_id, payload.class_id)
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

@router.post("/teacher/assignments", response_model=AssignmentCreateOut, dependencies=[Depends(require_role("teacher", "admin"))])
def teacher_upload_assignment(
    class_id: int = Form(...),
    title: str = Form(...),
    due_date: date = Form(...),
    description: str | None = Form(None),
    file: UploadFile | None = File(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    file_url = f"/uploads/{file.filename}" if file else None
    record = Assignment(
        school_id=current_user.school_id,
        teacher_id=current_user.id,
        class_id=class_id,
        title=title,
        description=description,
        due_date=due_date,
        file_url=file_url,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return AssignmentCreateOut(
        assignment_id=record.id,
        class_id=record.class_id,
        title=record.title,
        file_url=record.file_url,
        due_date=record.due_date,
        created_at=record.created_at,
    )

@router.get("/teacher/assignments/manage", response_model=TeacherAssignmentsManageOut, dependencies=[Depends(require_role("teacher", "admin"))])
def teacher_assignments_manage(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = date.today()
    assignments = db.query(Assignment).filter(
        Assignment.school_id == current_user.school_id,
        Assignment.teacher_id == current_user.id,
    ).order_by(Assignment.due_date.desc()).all()

    class_ids = list({a.class_id for a in assignments})
    class_name_map = {}
    if class_ids:
        classes = db.query(Class).filter(
            Class.school_id == current_user.school_id,
            Class.id.in_(class_ids),
        ).all()
        class_name_map = {c.id: c.name for c in classes}

    items = []
    for assignment in assignments:
        students = db.query(User).filter(
            User.school_id == current_user.school_id,
            User.class_id == assignment.class_id,
            User.role == "student",
        ).order_by(User.full_name.asc()).all()

        submissions = db.query(AssignmentSubmission).filter(
            AssignmentSubmission.assignment_id == assignment.id,
        ).all()
        submission_map = {s.student_id: s for s in submissions}

        student_items = []
        for student in students:
            sub = submission_map.get(student.id)
            student_items.append(
                TeacherAssignmentStudentOut(
                    student_id=student.id,
                    name=student.full_name,
                    status=sub.status if sub else "pending",
                )
            )

        items.append(
            TeacherAssignmentManageItemOut(
                assignment_id=assignment.id,
                class_id=assignment.class_id,
                class_name=class_name_map.get(assignment.class_id),
                title=assignment.title,
                due_date=assignment.due_date,
                overdue=assignment.due_date < today,
                students=student_items,
            )
        )

    return TeacherAssignmentsManageOut(assignments=items)

@router.put(
    "/teacher/assignments/{assignment_id}/students/{student_id}/status",
    response_model=TeacherAssignmentStatusOut,
    dependencies=[Depends(require_role("teacher", "admin"))],
)
def teacher_set_assignment_status(
    assignment_id: int,
    student_id: int,
    payload: TeacherAssignmentStatusIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    next_status = payload.status.strip().lower()
    if next_status not in ASSIGNMENT_STATUS:
        raise HTTPException(status_code=400, detail="Invalid assignment status")

    assignment = db.query(Assignment).filter(
        Assignment.id == assignment_id,
        Assignment.school_id == current_user.school_id,
        Assignment.teacher_id == current_user.id,
    ).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    student = db.query(User).filter(
        User.id == student_id,
        User.school_id == current_user.school_id,
        User.role == "student",
        User.class_id == assignment.class_id,
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found in assignment class")

    submission = db.query(AssignmentSubmission).filter(
        AssignmentSubmission.assignment_id == assignment.id,
        AssignmentSubmission.student_id == student.id,
    ).first()
    if not submission:
        submission = AssignmentSubmission(
            assignment_id=assignment.id,
            student_id=student.id,
            status=next_status,
        )
        db.add(submission)
    else:
        submission.status = next_status
    db.commit()

    return TeacherAssignmentStatusOut(
        assignment_id=assignment.id,
        student_id=student.id,
        status=next_status,
    )

@router.post(
    "/teacher/assignments/{assignment_id}/mark-overdue",
    response_model=TeacherAssignmentOverdueOut,
    dependencies=[Depends(require_role("teacher", "admin"))],
)
def teacher_mark_assignment_overdue(
    assignment_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    assignment = db.query(Assignment).filter(
        Assignment.id == assignment_id,
        Assignment.school_id == current_user.school_id,
        Assignment.teacher_id == current_user.id,
    ).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    if assignment.due_date >= date.today():
        raise HTTPException(status_code=400, detail="Due date is not over yet")

    students = db.query(User).filter(
        User.school_id == current_user.school_id,
        User.class_id == assignment.class_id,
        User.role == "student",
    ).all()
    student_ids = [s.id for s in students]

    submissions = db.query(AssignmentSubmission).filter(
        AssignmentSubmission.assignment_id == assignment.id,
        AssignmentSubmission.student_id.in_(student_ids),
    ).all() if student_ids else []
    submission_map = {s.student_id: s for s in submissions}

    updated = 0
    for student_id in student_ids:
        submission = submission_map.get(student_id)
        if not submission:
            db.add(
                AssignmentSubmission(
                    assignment_id=assignment.id,
                    student_id=student_id,
                    status="late",
                )
            )
            updated += 1
            continue
        if submission.status == "pending":
            submission.status = "late"
            updated += 1

    db.commit()
    return TeacherAssignmentOverdueOut(
        assignment_id=assignment.id,
        updated=updated,
        status="ok",
    )

@router.post("/teacher/marks", response_model=MarksOut, dependencies=[Depends(require_role("teacher", "admin"))])
def teacher_enter_marks(
    payload: MarksIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    for record in payload.records:
        db.add(
            Mark(
                school_id=current_user.school_id,
                teacher_id=current_user.id,
                class_id=payload.class_id,
                student_id=record.student_id,
                assessment_name=payload.assessment_name,
                marks=record.marks,
                max_marks=record.max_marks,
                date=payload.date,
            )
        )
    db.commit()
    return MarksOut(assessment_name=payload.assessment_name, saved=len(payload.records), status="ok")

# -------- Student Dashboard Endpoints --------

@router.get("/student/summary", response_model=StudentSummaryOut, dependencies=[Depends(require_role("student"))])
def student_summary(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    today = date.today()
    since = today - timedelta(days=30)
    rows = db.query(Attendance).filter(
        Attendance.school_id == current_user.school_id,
        Attendance.student_id == current_user.id,
        Attendance.date >= since,
    ).all()
    total = len(rows)
    present = len([r for r in rows if r.status == "present"])
    attendance_pct = round((present / total) * 100, 2) if total > 0 else 0.0

    pending_tasks = 0
    alerts = []
    if current_user.class_id:
        submissions = (
            db.query(Assignment, AssignmentSubmission)
            .outerjoin(
                AssignmentSubmission,
                and_(
                    AssignmentSubmission.assignment_id == Assignment.id,
                    AssignmentSubmission.student_id == current_user.id,
                ),
            )
            .filter(
                Assignment.school_id == current_user.school_id,
                Assignment.class_id == current_user.class_id,
            )
            .all()
        )
        for assignment, submission in submissions:
            status = submission.status if submission else "pending"
            if status in ("pending", "missing") and assignment.due_date >= today:
                pending_tasks += 1

    if attendance_pct < 90:
        alerts.append(f"Attendance below 90% ({attendance_pct}%)")
    if pending_tasks > 0:
        alerts.append(f"{pending_tasks} assignment(s) pending")

    return StudentSummaryOut(
        student_id=current_user.id,
        school_id=current_user.school_id,
        attendance_pct=attendance_pct,
        pending_tasks=pending_tasks,
        alerts=alerts,
    )

@router.get("/student/timetable/today", response_model=StudentTimetableOut, dependencies=[Depends(require_role("student"))])
def student_timetable_today(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    today = date.today()
    weekday = today.weekday()
    periods = {
        1: ("08:00", "08:45"),
        2: ("08:50", "09:35"),
        3: ("09:45", "10:30"),
        4: ("10:40", "11:25"),
        5: ("11:35", "12:20"),
        6: ("13:00", "13:45"),
    }
    schedule = []
    if current_user.class_id:
        rows = db.query(Timetable).filter(
            Timetable.school_id == current_user.school_id,
            Timetable.class_id == current_user.class_id,
            Timetable.day_of_week == weekday,
        ).order_by(Timetable.period).all()
        for row in rows:
            start_time, end_time = periods.get(row.period, ("--:--", "--:--"))
            schedule.append(
                ScheduleItemOut(
                    period=row.period,
                    start_time=start_time,
                    end_time=end_time,
                    subject=row.subject,
                    class_id=row.class_id,
                    room=None,
                )
            )
    return StudentTimetableOut(date=today, student_id=current_user.id, timetable=schedule)

@router.get("/student/assignments", response_model=StudentAssignmentsOut, dependencies=[Depends(require_role("student"))])
def student_assignments(
    status: str | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    assignments = []
    if current_user.class_id:
        rows = (
            db.query(Assignment, AssignmentSubmission)
            .outerjoin(
                AssignmentSubmission,
                and_(
                    AssignmentSubmission.assignment_id == Assignment.id,
                    AssignmentSubmission.student_id == current_user.id,
                ),
            )
            .filter(
                Assignment.school_id == current_user.school_id,
                Assignment.class_id == current_user.class_id,
            )
            .order_by(Assignment.due_date.desc())
            .all()
        )
        for assignment, submission in rows:
            item_status = submission.status if submission else "pending"
            if status and item_status != status:
                continue
            assignments.append(
                StudentAssignmentOut(
                    assignment_id=assignment.id,
                    title=assignment.title,
                    due_date=assignment.due_date,
                    status=item_status,
                    file_url=assignment.file_url,
                )
            )
    return StudentAssignmentsOut(student_id=current_user.id, assignments=assignments)

@router.get("/student/performance", response_model=StudentPerformanceOut, dependencies=[Depends(require_role("student"))])
def student_performance(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.query(Mark).filter(
        Mark.school_id == current_user.school_id,
        Mark.student_id == current_user.id,
    ).order_by(Mark.date.desc()).all()
    performance = []
    for row in rows:
        pct = round((row.marks / row.max_marks) * 100, 2) if row.max_marks else 0.0
        performance.append(
            StudentPerformanceItemOut(
                assessment_name=row.assessment_name,
                marks=row.marks,
                max_marks=row.max_marks,
                percentage=pct,
                date=row.date,
            )
        )
    return StudentPerformanceOut(student_id=current_user.id, performance=performance)

@router.get("/student/notices", response_model=StudentNoticesOut, dependencies=[Depends(require_role("student"))])
def student_notices(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.query(Notice).filter(
        Notice.school_id == current_user.school_id,
    ).order_by(Notice.created_at.desc()).all()
    notices = [
        StudentNoticeOut(
            notice_id=row.id,
            title=row.title,
            body=row.body,
            created_at=row.created_at,
        )
        for row in rows
    ]
    return StudentNoticesOut(student_id=current_user.id, notices=notices)

@router.get("/student/notices/unread", response_model=StudentNoticesOut, dependencies=[Depends(require_role("student"))])
def student_notices_unread(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.query(Notice).filter(
        Notice.school_id == current_user.school_id,
    ).order_by(Notice.created_at.desc()).all()

    read_notice_ids = {
        r.notice_id
        for r in db.query(NoticeRead).filter(NoticeRead.student_id == current_user.id).all()
    }

    notices = [
        StudentNoticeOut(
            notice_id=row.id,
            title=row.title,
            body=row.body,
            created_at=row.created_at,
        )
        for row in rows
        if row.id not in read_notice_ids
    ]
    return StudentNoticesOut(student_id=current_user.id, notices=notices)

@router.post("/student/notices/mark-read", dependencies=[Depends(require_role("student"))])
def student_mark_notices_read(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.query(Notice).filter(Notice.school_id == current_user.school_id).all()
    read_notice_ids = {
        r.notice_id
        for r in db.query(NoticeRead).filter(NoticeRead.student_id == current_user.id).all()
    }

    created = 0
    for notice in rows:
        if notice.id in read_notice_ids:
            continue
        db.add(NoticeRead(notice_id=notice.id, student_id=current_user.id))
        created += 1

    db.commit()
    return {"status": "ok", "marked": created}
