from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import and_, select
from sqlalchemy.orm import Session, joinedload, selectinload

from app.api.deps import get_current_user, require_role
from app.api.v1.common import (
    ASSESSMENT_TYPES,
    PERIOD_SLOTS,
    require_class,
    require_student,
    teacher_visible_students_query,
)
from app.db.session import get_db
from app.models.models import Assignment, AssignmentSubmission, Attendance, Class, Mark, Notice, Timetable, User
from app.schemas.schemas import (
    MarksIn,
    MarksOut,
    ScheduleItemOut,
    StudentInsightOut,
    StudentInsightsOut,
    TeacherScheduleOut,
    TeacherStudentAssignmentSummaryOut,
    TeacherStudentAttendanceOut,
    TeacherStudentDetailOut,
    TeacherStudentListItemOut,
    TeacherStudentMarkItemOut,
    TeacherStudentNoticeItemOut,
    TeacherStudentPerformanceSummaryOut,
    TeacherStudentsOut,
    TeacherSummaryOut,
)

router = APIRouter(prefix="/teacher", tags=["teacher"])


@router.get("/summary", response_model=TeacherSummaryOut, dependencies=[Depends(require_role("teacher"))])
def teacher_summary(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    today = date.today()
    weekday = today.weekday()

    if current_user.class_id is None:
        return TeacherSummaryOut(
            teacher_id=current_user.id,
            school_id=current_user.school_id,
            today_classes=0,
            pending_attendance=0,
            assignments_to_review=0,
            low_attendance_alerts=0,
        )

    today_classes = db.query(Timetable).filter(
        Timetable.school_id == current_user.school_id,
        Timetable.class_id == current_user.class_id,
        Timetable.day_of_week == weekday,
    ).count()

    attendance_today = db.query(Attendance.class_id).filter(
        Attendance.school_id == current_user.school_id,
        Attendance.class_id == current_user.class_id,
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
        Attendance.class_id == current_user.class_id,
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


@router.get("/schedule/today", response_model=TeacherScheduleOut, dependencies=[Depends(require_role("teacher"))])
def teacher_schedule_today(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    today = date.today()
    weekday = today.weekday()

    rows = []
    if current_user.class_id is not None:
        rows = db.query(Timetable).filter(
            Timetable.school_id == current_user.school_id,
            Timetable.class_id == current_user.class_id,
            Timetable.day_of_week == weekday,
        ).order_by(Timetable.period).all()

    schedule = []
    for row in rows:
        start_time, end_time = PERIOD_SLOTS.get(row.period, ("--:--", "--:--"))
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


@router.get("/students/insights", response_model=StudentInsightsOut, dependencies=[Depends(require_role("teacher"))])
def teacher_student_insights(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    today = date.today()
    since = today - timedelta(days=30)
    students = teacher_visible_students_query(current_user, db).all()
    student_ids = [student.id for student in students]

    if not student_ids:
        return StudentInsightsOut(
            below_attendance_threshold=[],
            missing_assignments=[],
        )

    attendance_rows = db.query(Attendance).filter(
        Attendance.school_id == current_user.school_id,
        Attendance.student_id.in_(student_ids),
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


@router.get("/students", response_model=TeacherStudentsOut, dependencies=[Depends(require_role("teacher"))])
def teacher_students(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    classes = db.query(Class).filter(Class.school_id == current_user.school_id).all()
    class_name_map = {klass.id: klass.name for klass in classes}
    students = (
        teacher_visible_students_query(current_user, db)
        .options(
            joinedload(User.assigned_class),
            selectinload(User.attendance_records),
            selectinload(User.marks_received),
        )
        .order_by(User.full_name.asc())
        .all()
    )

    class_ids = sorted({student.class_id for student in students if student.class_id is not None})
    student_ids = [student.id for student in students]
    class_assignments_map: dict[int, list[Assignment]] = {}
    if class_ids:
        assignments = (
            db.query(Assignment)
            .filter(
                Assignment.school_id == current_user.school_id,
                Assignment.class_id.in_(class_ids),
            )
            .all()
        )
        for assignment in assignments:
            class_assignments_map.setdefault(assignment.class_id, []).append(assignment)

    assignment_status_map: dict[tuple[int, int], str] = {}
    if student_ids:
        submissions = (
            db.query(AssignmentSubmission)
            .join(Assignment, AssignmentSubmission.assignment_id == Assignment.id)
            .filter(
                Assignment.school_id == current_user.school_id,
                AssignmentSubmission.student_id.in_(student_ids),
            )
            .all()
        )
        for submission in submissions:
            assignment_status_map[(submission.assignment_id, submission.student_id)] = submission.status

    items = []
    for student in students:
        attendance_rows = [
            row for row in student.attendance_records if row.school_id == current_user.school_id
        ]
        total_records = len(attendance_rows)
        present = sum(1 for row in attendance_rows if row.status == "present")
        attendance_pct = round((present / total_records) * 100, 2) if total_records else 0.0

        pending_assignments = 0
        if student.class_id is not None:
            class_assignments = class_assignments_map.get(student.class_id, [])
            for assignment in class_assignments:
                status = assignment_status_map.get((assignment.id, student.id), "pending")
                if status in ("pending", "missing"):
                    pending_assignments += 1

        mark_rows = [row for row in student.marks_received if row.school_id == current_user.school_id]
        average_score = round(
            sum((row.marks / row.max_marks) * 100 for row in mark_rows if row.max_marks) / len(mark_rows),
            2,
        ) if mark_rows else 0.0

        items.append(
            TeacherStudentListItemOut(
                student_id=student.id,
                full_name=student.full_name,
                email=student.email,
                class_id=student.class_id,
                class_name=class_name_map.get(student.class_id) if student.class_id is not None else None,
                attendance_pct=attendance_pct,
                pending_assignments=pending_assignments,
                average_score=average_score,
            )
        )

    return TeacherStudentsOut(students=items)


@router.get(
    "/students/{student_id}",
    response_model=TeacherStudentDetailOut,
    dependencies=[Depends(require_role("teacher"))],
)
def teacher_student_detail(
    student_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    student = (
        teacher_visible_students_query(current_user, db)
        .options(
            joinedload(User.assigned_class),
            selectinload(User.attendance_records),
            selectinload(User.marks_received),
        )
        .filter(User.id == student_id)
        .first()
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    class_name = student.assigned_class.name if student.assigned_class else None

    attendance_rows = [
        row for row in student.attendance_records if row.school_id == current_user.school_id
    ]
    total_records = len(attendance_rows)
    present = sum(1 for row in attendance_rows if row.status == "present")
    absent = sum(1 for row in attendance_rows if row.status == "absent")
    late = sum(1 for row in attendance_rows if row.status == "late")
    attendance_pct = round((present / total_records) * 100, 2) if total_records else 0.0

    pending = 0
    submitted = 0
    late_count = 0
    missing = 0
    if student.class_id is not None:
        assignment_rows = (
            db.query(Assignment, AssignmentSubmission)
            .outerjoin(
                AssignmentSubmission,
                and_(
                    AssignmentSubmission.assignment_id == Assignment.id,
                    AssignmentSubmission.student_id == student.id,
                ),
            )
            .filter(
                Assignment.school_id == current_user.school_id,
                Assignment.class_id == student.class_id,
            )
            .all()
        )
        for assignment, submission in assignment_rows:
            status = submission.status if submission else "pending"
            if status == "submitted":
                submitted += 1
            elif status == "late":
                late_count += 1
            elif status == "missing":
                missing += 1
            else:
                pending += 1

    mark_rows = sorted(
        [row for row in student.marks_received if row.school_id == current_user.school_id],
        key=lambda row: row.date,
        reverse=True,
    )
    average_score = round(
        sum((row.marks / row.max_marks) * 100 for row in mark_rows if row.max_marks) / len(mark_rows),
        2,
    ) if mark_rows else 0.0
    subject_totals: dict[str, list[float]] = {}
    for row in mark_rows:
        if not row.max_marks:
            continue
        subject_totals.setdefault(row.subject, []).append((row.marks / row.max_marks) * 100)
    by_subject = {
        subject: round(sum(values) / len(values), 2)
        for subject, values in subject_totals.items()
    }

    recent_marks = [
        TeacherStudentMarkItemOut(
            subject=row.subject,
            assessment_type=row.assessment_type,
            assessment_name=row.assessment_name,
            marks=row.marks,
            max_marks=row.max_marks,
            percentage=round((row.marks / row.max_marks) * 100, 2) if row.max_marks else 0.0,
            date=row.date,
        )
        for row in mark_rows[:6]
    ]

    recent_notices = [
        TeacherStudentNoticeItemOut(
            notice_id=row.id,
            title=row.title,
            created_at=row.created_at,
        )
        for row in db.query(Notice).filter(
            Notice.school_id == current_user.school_id,
        ).order_by(Notice.created_at.desc()).limit(5).all()
    ]

    return TeacherStudentDetailOut(
        student_id=student.id,
        full_name=student.full_name,
        email=student.email,
        class_id=student.class_id,
        class_name=class_name,
        attendance=TeacherStudentAttendanceOut(
            total_records=total_records,
            present=present,
            absent=absent,
            late=late,
            attendance_pct=attendance_pct,
        ),
        assignments=TeacherStudentAssignmentSummaryOut(
            pending=pending,
            submitted=submitted,
            late=late_count,
            missing=missing,
        ),
        performance=TeacherStudentPerformanceSummaryOut(
            average_score=average_score,
            by_subject=by_subject,
        ),
        recent_marks=recent_marks,
        recent_notices=recent_notices,
    )


@router.post("/marks", response_model=MarksOut, dependencies=[Depends(require_role("teacher"))])
def teacher_enter_marks(
    payload: MarksIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    subject = payload.subject.strip()
    assessment_type = payload.assessment_type.strip().lower()
    if not subject:
        raise HTTPException(status_code=400, detail="Subject is required")
    if assessment_type not in ASSESSMENT_TYPES:
        raise HTTPException(status_code=400, detail="Invalid assessment type")
    require_class(db, current_user.school_id, payload.class_id)
    for record in payload.records:
        require_student(db, current_user.school_id, record.student_id, payload.class_id)
        existing = db.query(Mark).filter(
            Mark.school_id == current_user.school_id,
            Mark.class_id == payload.class_id,
            Mark.student_id == record.student_id,
            Mark.subject == subject,
            Mark.assessment_type == assessment_type,
            Mark.assessment_name == payload.assessment_name,
            Mark.date == payload.date,
        ).first()
        if existing:
            existing.teacher_id = current_user.id
            existing.marks = record.marks
            existing.max_marks = record.max_marks
            continue
        db.add(
            Mark(
                school_id=current_user.school_id,
                teacher_id=current_user.id,
                class_id=payload.class_id,
                student_id=record.student_id,
                subject=subject,
                assessment_type=assessment_type,
                assessment_name=payload.assessment_name,
                marks=record.marks,
                max_marks=record.max_marks,
                date=payload.date,
            )
        )
    db.commit()
    return MarksOut(
        subject=subject,
        assessment_type=assessment_type,
        assessment_name=payload.assessment_name,
        saved=len(payload.records),
        status="ok",
    )
