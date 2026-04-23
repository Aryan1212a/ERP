from datetime import date

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session, joinedload, selectinload

from app.api.deps import get_current_user, require_role
from app.api.v1.common import ASSIGNMENT_STATUS, require_class
from app.db.session import get_db
from app.models.models import Assignment, AssignmentSubmission, Class, User
from app.schemas.schemas import (
    AssignmentCreateOut,
    TeacherAssignmentManageItemOut,
    TeacherAssignmentOverdueOut,
    TeacherAssignmentsManageOut,
    TeacherAssignmentStatusIn,
    TeacherAssignmentStatusOut,
    TeacherAssignmentStudentOut,
)

router = APIRouter(prefix="/teacher/assignments", tags=["assignments"])


@router.post("", response_model=AssignmentCreateOut, dependencies=[Depends(require_role("teacher"))])
def teacher_upload_assignment(
    class_id: int = Form(...),
    title: str = Form(...),
    due_date: date = Form(...),
    description: str | None = Form(None),
    file: UploadFile | None = File(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_class(db, current_user.school_id, class_id)
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


@router.get("/manage", response_model=TeacherAssignmentsManageOut, dependencies=[Depends(require_role("teacher"))])
def teacher_assignments_manage(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = date.today()
    assignments = (
        db.query(Assignment)
        .options(
            joinedload(Assignment.class_room).selectinload(Class.students),
            selectinload(Assignment.submissions),
        )
        .filter(
            Assignment.school_id == current_user.school_id,
            Assignment.teacher_id == current_user.id,
        )
        .order_by(Assignment.due_date.desc())
        .all()
    )

    items = []
    for assignment in assignments:
        students = sorted(
            [
                student
                for student in (assignment.class_room.students if assignment.class_room else [])
                if student.school_id == current_user.school_id and student.role == "student"
            ],
            key=lambda student: student.full_name,
        )
        submission_map = {submission.student_id: submission for submission in assignment.submissions}

        student_items = []
        for student in students:
            submission = submission_map.get(student.id)
            student_items.append(
                TeacherAssignmentStudentOut(
                    student_id=student.id,
                    name=student.full_name,
                    status=submission.status if submission else "pending",
                )
            )

        items.append(
            TeacherAssignmentManageItemOut(
                assignment_id=assignment.id,
                class_id=assignment.class_id,
                class_name=assignment.class_room.name if assignment.class_room else None,
                title=assignment.title,
                description=assignment.description,
                file_url=assignment.file_url,
                due_date=assignment.due_date,
                overdue=assignment.due_date < today,
                students=student_items,
            )
        )

    return TeacherAssignmentsManageOut(assignments=items)


@router.put(
    "/{assignment_id}/students/{student_id}/status",
    response_model=TeacherAssignmentStatusOut,
    dependencies=[Depends(require_role("teacher"))],
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
    "/{assignment_id}/mark-overdue",
    response_model=TeacherAssignmentOverdueOut,
    dependencies=[Depends(require_role("teacher"))],
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
    student_ids = [student.id for student in students]

    submissions = (
        db.query(AssignmentSubmission).filter(
            AssignmentSubmission.assignment_id == assignment.id,
            AssignmentSubmission.student_id.in_(student_ids),
        ).all()
        if student_ids
        else []
    )
    submission_map = {submission.student_id: submission for submission in submissions}

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


@router.delete(
    "/{assignment_id}",
    dependencies=[Depends(require_role("teacher"))],
)
def teacher_delete_assignment(
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

    db.delete(assignment)
    db.commit()
    return {"deleted": True}
