from sqlalchemy import Column, Date, DateTime, ForeignKey, Boolean, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import relationship
from app.db.session import Base
import datetime as dt


class School(Base):
    __tablename__ = "colleges"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=dt.datetime.utcnow)

    users = relationship("User", back_populates="school")
    classes = relationship("Class", back_populates="school")
    attendance_records = relationship("Attendance", back_populates="school")
    timetable_entries = relationship("Timetable", back_populates="school")
    fees = relationship("Fee", back_populates="school")
    notices = relationship("Notice", back_populates="school")
    assignments = relationship("Assignment", back_populates="school")
    marks = relationship("Mark", back_populates="school")
    departments = relationship("Department", back_populates="school")
    programs = relationship("Program", back_populates="school")
    courses = relationship("Course", back_populates="school")
    academic_terms = relationship("AcademicTerm", back_populates="school")
    course_offerings = relationship("CourseOffering", back_populates="school")


class Department(Base):
    __tablename__ = "departments"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("colleges.id", ondelete="CASCADE"), index=True, nullable=False)
    name = Column(String(150), nullable=False)
    code = Column(String(20), nullable=False)

    school = relationship("School", back_populates="departments")
    programs = relationship("Program", back_populates="department")
    courses = relationship("Course", back_populates="department")


class Program(Base):
    __tablename__ = "programs"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("colleges.id", ondelete="CASCADE"), index=True, nullable=False)
    department_id = Column(Integer, ForeignKey("departments.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(150), nullable=False)
    code = Column(String(20), nullable=False)
    duration_years = Column(Integer, nullable=False)

    school = relationship("School", back_populates="programs")
    department = relationship("Department", back_populates="programs")


class Course(Base):
    __tablename__ = "courses"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("colleges.id", ondelete="CASCADE"), index=True, nullable=False)
    department_id = Column(Integer, ForeignKey("departments.id", ondelete="CASCADE"), nullable=False)
    code = Column(String(20), nullable=False)
    title = Column(String(200), nullable=False)
    credits = Column(Integer, nullable=False, default=3)

    school = relationship("School", back_populates="courses")
    department = relationship("Department", back_populates="courses")
    offerings = relationship("CourseOffering", back_populates="course")


class AcademicTerm(Base):
    __tablename__ = "academic_terms"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("colleges.id", ondelete="CASCADE"), index=True, nullable=False)
    name = Column(String(80), nullable=False)
    starts_on = Column(Date, nullable=False)
    ends_on = Column(Date, nullable=False)

    school = relationship("School", back_populates="academic_terms")
    offerings = relationship("CourseOffering", back_populates="term")


class CourseOffering(Base):
    __tablename__ = "course_offerings"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("colleges.id", ondelete="CASCADE"), index=True, nullable=False)
    course_id = Column(Integer, ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    term_id = Column(Integer, ForeignKey("academic_terms.id", ondelete="CASCADE"), nullable=False)
    faculty_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    section = Column(String(20), nullable=False, default="A")
    room = Column(String(50), nullable=True)

    school = relationship("School", back_populates="course_offerings")
    course = relationship("Course", back_populates="offerings")
    term = relationship("AcademicTerm", back_populates="offerings")
    enrollments = relationship("Enrollment", back_populates="offering", cascade="all, delete-orphan")


class Enrollment(Base):
    __tablename__ = "enrollments"
    __table_args__ = (UniqueConstraint("offering_id", "student_id", name="uq_enrollment_offering_student"),)
    id = Column(Integer, primary_key=True, index=True)
    offering_id = Column(Integer, ForeignKey("course_offerings.id", ondelete="CASCADE"), index=True, nullable=False)
    student_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    enrolled_at = Column(DateTime, default=dt.datetime.utcnow, nullable=False)
    status = Column(String(20), nullable=False, default="enrolled")

    offering = relationship("CourseOffering", back_populates="enrollments")
    student = relationship("User")


class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("colleges.id", ondelete="CASCADE"), index=True, nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    full_name = Column(String(255), nullable=False)
    username = Column(String(64), unique=True, index=True, nullable=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(50), default="student")
    is_active = Column(Boolean, default=True)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="SET NULL"), nullable=True)
    must_change_password = Column(Boolean, default=True)
    created_at = Column(DateTime, default=dt.datetime.utcnow)

    school = relationship("School", back_populates="users")
    assigned_class = relationship("Class", foreign_keys=[class_id], back_populates="students")
    teaching_class = relationship("Class", foreign_keys="Class.class_teacher_id", back_populates="class_teacher", uselist=False)
    attendance_records = relationship("Attendance", foreign_keys="Attendance.student_id", back_populates="student")
    fees = relationship("Fee", foreign_keys="Fee.student_id", back_populates="student")
    notices_read = relationship("NoticeRead", foreign_keys="NoticeRead.student_id", back_populates="student")
    teacher_assignments = relationship("Assignment", foreign_keys="Assignment.teacher_id", back_populates="teacher")
    assignment_submissions = relationship("AssignmentSubmission", foreign_keys="AssignmentSubmission.student_id", back_populates="student")
    marks_received = relationship("Mark", foreign_keys="Mark.student_id", back_populates="student")
    marks_given = relationship("Mark", foreign_keys="Mark.teacher_id", back_populates="teacher")
    sent_notices = relationship("Notice", back_populates="sender")


class Class(Base):
    __tablename__ = "classes"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("colleges.id", ondelete="CASCADE"), index=True, nullable=False)
    name = Column(String(100), nullable=False)
    class_teacher_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    school = relationship("School", back_populates="classes")
    class_teacher = relationship("User", foreign_keys=[class_teacher_id], back_populates="teaching_class")
    students = relationship("User", foreign_keys="User.class_id", back_populates="assigned_class")
    attendance_records = relationship("Attendance", back_populates="class_room")
    timetable_entries = relationship("Timetable", back_populates="class_room")
    assignments = relationship("Assignment", back_populates="class_room")
    marks = relationship("Mark", back_populates="class_room")


class Attendance(Base):
    __tablename__ = "attendance"
    __table_args__ = (
        UniqueConstraint("student_id", "date", name="uq_attendance_student_date"),
    )

    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("colleges.id", ondelete="CASCADE"), index=True, nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    date = Column(Date, nullable=False)
    status = Column(String(20), nullable=False)

    school = relationship("School", back_populates="attendance_records")
    class_room = relationship("Class", back_populates="attendance_records")
    student = relationship("User", foreign_keys=[student_id], back_populates="attendance_records")


class Timetable(Base):
    __tablename__ = "timetable"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("colleges.id", ondelete="CASCADE"), index=True, nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    day_of_week = Column(Integer, nullable=False)
    period = Column(Integer, nullable=False)
    subject = Column(String(100), nullable=False)

    school = relationship("School", back_populates="timetable_entries")
    class_room = relationship("Class", back_populates="timetable_entries")


class Fee(Base):
    __tablename__ = "fees"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("colleges.id", ondelete="CASCADE"), index=True, nullable=False)
    student_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    amount = Column(Integer, nullable=False)
    due_date = Column(Date, nullable=False)
    status = Column(String(20), default="pending")

    school = relationship("School", back_populates="fees")
    student = relationship("User", foreign_keys=[student_id], back_populates="fees")


class Notice(Base):
    __tablename__ = "notices"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("colleges.id", ondelete="CASCADE"), index=True, nullable=False)
    title = Column(String(255), nullable=False)
    body = Column(Text, nullable=False)
    created_at = Column(DateTime, default=dt.datetime.utcnow)

    school = relationship("School", back_populates="notices")
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    sender = relationship("User", back_populates="sent_notices")
    reads = relationship("NoticeRead", back_populates="notice")


class NoticeRead(Base):
    __tablename__ = "notice_reads"
    id = Column(Integer, primary_key=True, index=True)
    notice_id = Column(Integer, ForeignKey("notices.id", ondelete="CASCADE"), index=True, nullable=False)
    student_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    read_at = Column(DateTime, default=dt.datetime.utcnow)

    notice = relationship("Notice", back_populates="reads")
    student = relationship("User", foreign_keys=[student_id], back_populates="notices_read")


class Assignment(Base):
    __tablename__ = "assignments"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("colleges.id", ondelete="CASCADE"), index=True, nullable=False)
    teacher_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    due_date = Column(Date, nullable=False)
    file_url = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=dt.datetime.utcnow)

    school = relationship("School", back_populates="assignments")
    teacher = relationship("User", foreign_keys=[teacher_id], back_populates="teacher_assignments")
    class_room = relationship("Class", back_populates="assignments")
    submissions = relationship("AssignmentSubmission", back_populates="assignment", cascade="all, delete-orphan")


class AssignmentSubmission(Base):
    __tablename__ = "assignment_submissions"
    __table_args__ = (
        UniqueConstraint("assignment_id", "student_id", name="uq_assignment_submission_student"),
    )

    id = Column(Integer, primary_key=True, index=True)
    assignment_id = Column(Integer, ForeignKey("assignments.id", ondelete="CASCADE"), index=True, nullable=False)
    student_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    status = Column(String(20), default="submitted")  # submitted | missing | reviewed
    submitted_at = Column(DateTime, default=dt.datetime.utcnow)

    assignment = relationship("Assignment", back_populates="submissions")
    student = relationship("User", foreign_keys=[student_id], back_populates="assignment_submissions")


class Mark(Base):
    __tablename__ = "marks"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("colleges.id", ondelete="CASCADE"), index=True, nullable=False)
    teacher_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    subject = Column(String(100), nullable=False, default="General")
    assessment_type = Column(String(20), nullable=False, default="test")
    assessment_name = Column(String(255), nullable=False)
    marks = Column(Integer, nullable=False)
    max_marks = Column(Integer, nullable=False)
    date = Column(Date, nullable=False)

    school = relationship("School", back_populates="marks")
    teacher = relationship("User", foreign_keys=[teacher_id], back_populates="marks_given")
    class_room = relationship("Class", back_populates="marks")
    student = relationship("User", foreign_keys=[student_id], back_populates="marks_received")
