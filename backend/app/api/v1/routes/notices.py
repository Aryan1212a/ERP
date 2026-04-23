from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_role
from app.db.session import get_db
from app.models.models import Notice, NoticeRead, User
from app.schemas.schemas import (
    NoticeCreate,
    NoticeOut,
    StudentNoticeOut,
    StudentNoticesOut,
)

router = APIRouter(prefix="/notices", tags=["notices"])
student_router = APIRouter(prefix="/student/notices", tags=["notices"])


# =========================
# CREATE NOTICE
# =========================
@router.post(
    "",
    response_model=NoticeOut,
    dependencies=[Depends(require_role("admin", "teacher"))],
)
def create_notice(
    notice: NoticeCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = Notice(
        school_id=current_user.school_id,
        sender_id=current_user.id,
        **notice.dict()
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


# =========================
# LIST NOTICES (ADMIN/TEACHER)
# =========================
@router.get(
    "",
    response_model=list[NoticeOut],
    dependencies=[Depends(require_role("admin", "teacher"))],
)
def list_notices(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(Notice)
        .filter(Notice.school_id == current_user.school_id)
        .order_by(Notice.created_at.desc())
        .all()
    )


# =========================
# DELETE NOTICE
# =========================
@router.delete(
    "/{notice_id}",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_role("admin", "teacher"))],
)
def delete_notice(
    notice_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    notice = (
        db.query(Notice)
        .filter(
            Notice.id == notice_id,
            Notice.school_id == current_user.school_id,
        )
        .first()
    )

    if not notice:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notice not found",
        )

    # Only admin OR sender can delete
    if current_user.role != "admin" and notice.sender_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not allowed to delete this notice",
        )

    # Delete related read records (important if no cascade)
    db.query(NoticeRead).filter(
        NoticeRead.notice_id == notice_id
    ).delete()

    db.delete(notice)
    db.commit()

    return {"status": "success", "message": "Notice deleted"}


# =========================
# STUDENT: ALL NOTICES
# =========================
@student_router.get(
    "",
    response_model=StudentNoticesOut,
    dependencies=[Depends(require_role("student"))],
)
def student_notices(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(Notice, User.full_name.label("sender_name"))
        .join(User, Notice.sender_id == User.id)
        .filter(Notice.school_id == current_user.school_id)
        .order_by(Notice.created_at.desc())
        .all()
    )

    notices = [
        StudentNoticeOut(
            notice_id=row.Notice.id,
            title=row.Notice.title,
            body=row.Notice.body,
            created_at=row.Notice.created_at,
            sender_name=row.sender_name,
        )
        for row in rows
    ]

    return StudentNoticesOut(
        student_id=current_user.id,
        notices=notices
    )


# =========================
# STUDENT: UNREAD NOTICES
# =========================
@student_router.get(
    "/unread",
    response_model=StudentNoticesOut,
    dependencies=[Depends(require_role("student"))],
)
def student_notices_unread(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(Notice, User.full_name.label("sender_name"))
        .join(User, Notice.sender_id == User.id)
        .filter(Notice.school_id == current_user.school_id)
        .order_by(Notice.created_at.desc())
        .all()
    )

    read_notice_ids = {
        row.notice_id
        for row in db.query(NoticeRead)
        .filter(NoticeRead.student_id == current_user.id)
        .all()
    }

    notices = [
        StudentNoticeOut(
            notice_id=row.Notice.id,
            title=row.Notice.title,
            body=row.Notice.body,
            created_at=row.Notice.created_at,
            sender_name=row.sender_name,
        )
        for row in rows
        if row.Notice.id not in read_notice_ids
    ]

    return StudentNoticesOut(
        student_id=current_user.id,
        notices=notices
    )


# =========================
# STUDENT: MARK ALL AS READ
# =========================
@student_router.post(
    "/mark-read",
    dependencies=[Depends(require_role("student"))],
)
def student_mark_notices_read(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = db.query(Notice).filter(
        Notice.school_id == current_user.school_id
    ).all()

    read_notice_ids = {
        row.notice_id
        for row in db.query(NoticeRead)
        .filter(NoticeRead.student_id == current_user.id)
        .all()
    }

    created = 0

    for notice in rows:
        if notice.id in read_notice_ids:
            continue

        db.add(
            NoticeRead(
                notice_id=notice.id,
                student_id=current_user.id
            )
        )
        created += 1

    db.commit()

    return {"status": "ok", "marked": created}
