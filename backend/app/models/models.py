from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Boolean, Text, Date
from sqlalchemy.orm import relationship
from app.db.session import Base
import datetime as dt

class School(Base):
    __tablename__ = "schools"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=dt.datetime.utcnow)

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), index=True, nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    full_name = Column(String(255), nullable=False)
    username = Column(String(64), unique=True, index=True, nullable=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(50), default="student")
    is_active = Column(Boolean, default=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=True)
    must_change_password = Column(Boolean, default=True)
    created_at = Column(DateTime, default=dt.datetime.utcnow)

class Class(Base):
    __tablename__ = "classes"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), index=True, nullable=False)
    name = Column(String(100), nullable=False)
    class_teacher_id = Column(Integer, ForeignKey("users.id"), nullable=True)

class Attendance(Base):
    __tablename__ = "attendance"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), index=True, nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    student_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    date = Column(Date, nullable=False)
    status = Column(String(20), nullable=False)

class Timetable(Base):
    __tablename__ = "timetable"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), index=True, nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    day_of_week = Column(Integer, nullable=False)
    period = Column(Integer, nullable=False)
    subject = Column(String(100), nullable=False)

class Fee(Base):
    __tablename__ = "fees"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), index=True, nullable=False)
    student_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    amount = Column(Integer, nullable=False)
    due_date = Column(Date, nullable=False)
    status = Column(String(20), default="pending")

class Notice(Base):
    __tablename__ = "notices"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), index=True, nullable=False)
    title = Column(String(255), nullable=False)
    body = Column(Text, nullable=False)
    created_at = Column(DateTime, default=dt.datetime.utcnow)

class NoticeRead(Base):
    __tablename__ = "notice_reads"
    id = Column(Integer, primary_key=True, index=True)
    notice_id = Column(Integer, ForeignKey("notices.id"), index=True, nullable=False)
    student_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    read_at = Column(DateTime, default=dt.datetime.utcnow)

class Assignment(Base):
    __tablename__ = "assignments"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), index=True, nullable=False)
    teacher_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    due_date = Column(Date, nullable=False)
    file_url = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=dt.datetime.utcnow)

class AssignmentSubmission(Base):
    __tablename__ = "assignment_submissions"
    id = Column(Integer, primary_key=True, index=True)
    assignment_id = Column(Integer, ForeignKey("assignments.id"), index=True, nullable=False)
    student_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    status = Column(String(20), default="submitted")  # submitted | missing | reviewed
    submitted_at = Column(DateTime, default=dt.datetime.utcnow)

class Mark(Base):
    __tablename__ = "marks"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), index=True, nullable=False)
    teacher_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    student_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    subject = Column(String(100), nullable=False, default="General")
    assessment_type = Column(String(20), nullable=False, default="test")
    assessment_name = Column(String(255), nullable=False)
    marks = Column(Integer, nullable=False)
    max_marks = Column(Integer, nullable=False)
    date = Column(Date, nullable=False)
