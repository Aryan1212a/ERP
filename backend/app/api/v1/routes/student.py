from datetime import date, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import and_
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_role
from app.api.v1.common import PERIOD_SLOTS
from app.db.session import get_db
from app.models.models import Assignment, AssignmentSubmission, Attendance, Mark, Timetable, User
from app.schemas.schemas import (
    StudentAttendanceItemOut,
    StudentAttendanceOut,
    ScheduleItemOut,
    StudentAssignmentOut,
    StudentAssignmentsOut,
    StudentPerformanceItemOut,
    StudentPerformanceOut,
    StudentSummaryOut,
    StudentTimetableOut,
)

router = APIRouter(prefix="/student", tags=["student"])


@router.get("/summary", response_model=StudentSummaryOut, dependencies=[Depends(require_role("student"))])
def student_summary(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    today = date.today()
    since = today - timedelta(days=30)
    rows = db.query(Attendance).filter(
        Attendance.school_id == current_user.school_id,
        Attendance.student_id == current_user.id,
        Attendance.date >= since,
    ).all()
    total = len(rows)
    present = len([row for row in rows if row.status == "present"])
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


@router.get("/timetable/today", response_model=StudentTimetableOut, dependencies=[Depends(require_role("student"))])
def student_timetable_today(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    today = date.today()
    weekday = today.weekday()
    schedule = []
    if current_user.class_id:
        rows = db.query(Timetable).filter(
            Timetable.school_id == current_user.school_id,
            Timetable.class_id == current_user.class_id,
            Timetable.day_of_week == weekday,
        ).order_by(Timetable.period).all()
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
    return StudentTimetableOut(date=today, student_id=current_user.id, timetable=schedule)


@router.get("/assignments", response_model=StudentAssignmentsOut, dependencies=[Depends(require_role("student"))])
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


@router.get("/attendance", response_model=StudentAttendanceOut, dependencies=[Depends(require_role("student"))])
def student_attendance(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = (
        db.query(Attendance)
        .filter(
            Attendance.school_id == current_user.school_id,
            Attendance.student_id == current_user.id,
        )
        .order_by(Attendance.date.desc())
        .all()
    )
    return StudentAttendanceOut(
        student_id=current_user.id,
        attendance=[
            StudentAttendanceItemOut(
                date=row.date,
                status=row.status,
                class_id=row.class_id,
            )
            for row in rows
        ],
    )


@router.get("/performance", response_model=StudentPerformanceOut, dependencies=[Depends(require_role("student"))])
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
                subject=row.subject,
                assessment_type=row.assessment_type,
                assessment_name=row.assessment_name,
                marks=row.marks,
                max_marks=row.max_marks,
                percentage=pct,
                date=row.date,
            )
        )
    return StudentPerformanceOut(student_id=current_user.id, performance=performance)
