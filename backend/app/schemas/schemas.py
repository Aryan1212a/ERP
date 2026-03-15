from pydantic import BaseModel, EmailStr, ConfigDict
from datetime import date, datetime

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    role: str
    must_change_password: bool

class UserCreate(BaseModel):
    school_id: int
    email: EmailStr
    full_name: str
    password: str
    class_id: int | None = None

class UserOut(BaseModel):
    id: int
    school_id: int
    email: EmailStr
    full_name: str
    role: str
    class_id: int | None = None
    username: str | None = None
    must_change_password: bool | None = None
    model_config = ConfigDict(from_attributes=True)

class LoginIn(BaseModel):
    email: EmailStr
    password: str

class StudentCreate(BaseModel):
    school_id: int
    email: EmailStr
    full_name: str
    password: str
    class_id: int | None = None

class AdminCreateUserIn(BaseModel):
    role: str  # student | teacher
    full_name: str
    email: EmailStr
    class_id: int | None = None

class AdminCreateUserOut(BaseModel):
    id: int
    school_id: int
    role: str
    full_name: str
    email: EmailStr
    username: str
    temporary_password: str
    must_change_password: bool

class AdminResetPasswordOut(BaseModel):
    user_id: int
    temporary_password: str
    must_change_password: bool

class ChangePasswordIn(BaseModel):
    old_password: str
    new_password: str

class ChangePasswordOut(BaseModel):
    status: str

class ClassCreate(BaseModel):
    name: str

class ClassOut(ClassCreate):
    id: int
    school_id: int
    model_config = ConfigDict(from_attributes=True)

class AttendanceCreate(BaseModel):
    class_id: int
    student_id: int
    date: date
    status: str

class AttendanceOut(AttendanceCreate):
    id: int
    school_id: int
    model_config = ConfigDict(from_attributes=True)

class TimetableCreate(BaseModel):
    class_id: int
    day_of_week: int
    period: int
    subject: str

class TimetableOut(TimetableCreate):
    id: int
    school_id: int
    model_config = ConfigDict(from_attributes=True)

class FeeCreate(BaseModel):
    student_id: int
    amount: int
    due_date: date
    status: str = "pending"

class FeeOut(FeeCreate):
    id: int
    school_id: int
    model_config = ConfigDict(from_attributes=True)

class NoticeCreate(BaseModel):
    title: str
    body: str

class NoticeOut(NoticeCreate):
    id: int
    school_id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class TeacherSummaryOut(BaseModel):
    teacher_id: int
    school_id: int
    today_classes: int
    pending_attendance: int
    assignments_to_review: int
    low_attendance_alerts: int

class ScheduleItemOut(BaseModel):
    period: int
    start_time: str
    end_time: str
    subject: str
    class_id: int
    room: str | None = None

class TeacherScheduleOut(BaseModel):
    date: date
    teacher_id: int
    schedule: list[ScheduleItemOut]

class StudentInsightOut(BaseModel):
    student_id: int
    name: str
    reason: str

class StudentInsightsOut(BaseModel):
    below_attendance_threshold: list[StudentInsightOut]
    missing_assignments: list[StudentInsightOut]

class TeacherAttendanceRecordIn(BaseModel):
    student_id: int
    status: str

class TeacherAttendanceIn(BaseModel):
    class_id: int
    date: date
    records: list[TeacherAttendanceRecordIn]

class TeacherAttendanceOut(BaseModel):
    class_id: int
    date: date
    saved: int
    status: str

class AssignmentCreateOut(BaseModel):
    assignment_id: int
    class_id: int
    title: str
    file_url: str | None = None
    due_date: date
    created_at: datetime

class TeacherAssignmentStudentOut(BaseModel):
    student_id: int
    name: str
    status: str

class TeacherAssignmentManageItemOut(BaseModel):
    assignment_id: int
    class_id: int
    class_name: str | None = None
    title: str
    due_date: date
    overdue: bool
    students: list[TeacherAssignmentStudentOut]

class TeacherAssignmentsManageOut(BaseModel):
    assignments: list[TeacherAssignmentManageItemOut]

class TeacherAssignmentStatusIn(BaseModel):
    status: str

class TeacherAssignmentStatusOut(BaseModel):
    assignment_id: int
    student_id: int
    status: str

class TeacherAssignmentOverdueOut(BaseModel):
    assignment_id: int
    updated: int
    status: str

class MarksRecordIn(BaseModel):
    student_id: int
    marks: int
    max_marks: int

class MarksIn(BaseModel):
    class_id: int
    assessment_name: str
    date: date
    records: list[MarksRecordIn]

class MarksOut(BaseModel):
    assessment_name: str
    saved: int
    status: str

class StudentSummaryOut(BaseModel):
    student_id: int
    school_id: int
    attendance_pct: float
    pending_tasks: int
    alerts: list[str]

class StudentTimetableOut(BaseModel):
    date: date
    student_id: int
    timetable: list[ScheduleItemOut]

class StudentAssignmentOut(BaseModel):
    assignment_id: int
    title: str
    due_date: date
    status: str
    file_url: str | None = None

class StudentAssignmentsOut(BaseModel):
    student_id: int
    assignments: list[StudentAssignmentOut]

class StudentPerformanceItemOut(BaseModel):
    assessment_name: str
    marks: int
    max_marks: int
    percentage: float
    date: date

class StudentPerformanceOut(BaseModel):
    student_id: int
    performance: list[StudentPerformanceItemOut]

class StudentNoticeOut(BaseModel):
    notice_id: int
    title: str
    body: str
    created_at: datetime

class StudentNoticesOut(BaseModel):
    student_id: int
    notices: list[StudentNoticeOut]
