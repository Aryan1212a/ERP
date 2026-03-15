from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from datetime import date
from app.api.v1.router import api_router
from app.db.session import Base, engine, SessionLocal
from app.models.models import (
    School, User, Class, Timetable, Attendance,
    Assignment, AssignmentSubmission
)
from app.core.security import hash_password

app = FastAPI(title="School ERP")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://127.0.0.1",
    ],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")

def _seed_demo_data() -> None:
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        school = db.query(School).filter(School.name == "Demo School").first()
        if not school:
            school = School(name="Demo School")
            db.add(school)
            db.commit()
            db.refresh(school)

        demo_users = [
            ("admin@demo.com", "Admin User", "admin", "admin123"),
            ("teacher@demo.com", "Teacher User", "teacher", "teacher123"),
            ("student@demo.com", "Student User", "student", "student123"),
        ]
        for email, name, role, password in demo_users:
            existing = db.query(User).filter(User.email == email).first()
            if not existing:
                db.add(
                    User(
                        school_id=school.id,
                        email=email,
                        full_name=name,
                        role=role,
                        password_hash=hash_password(password),
                    )
                )
        db.commit()

        teacher = db.query(User).filter(User.email == "teacher@demo.com").first()
        student = db.query(User).filter(User.email == "student@demo.com").first()

        demo_class = db.query(Class).filter(
            Class.school_id == school.id,
            Class.name == "Grade 8 - A",
        ).first()
        if not demo_class:
            demo_class = Class(school_id=school.id, name="Grade 8 - A")
            db.add(demo_class)
            db.commit()
            db.refresh(demo_class)

        today = date.today()
        weekday = today.weekday()
        existing_tt = db.query(Timetable).filter(
            Timetable.school_id == school.id,
            Timetable.day_of_week == weekday,
            Timetable.class_id == demo_class.id,
        ).first()
        if not existing_tt:
            db.add_all(
                [
                    Timetable(
                        school_id=school.id,
                        class_id=demo_class.id,
                        day_of_week=weekday,
                        period=1,
                        subject="Mathematics",
                    ),
                    Timetable(
                        school_id=school.id,
                        class_id=demo_class.id,
                        day_of_week=weekday,
                        period=2,
                        subject="Science",
                    ),
                ]
            )
            db.commit()

        if teacher and student:
            existing_att = db.query(Attendance).filter(
                Attendance.school_id == school.id,
                Attendance.class_id == demo_class.id,
                Attendance.student_id == student.id,
                Attendance.date == today,
            ).first()
            if not existing_att:
                db.add(
                    Attendance(
                        school_id=school.id,
                        class_id=demo_class.id,
                        student_id=student.id,
                        date=today,
                        status="present",
                    )
                )
                db.commit()

            if student.class_id != demo_class.id:
                student.class_id = demo_class.id
                db.commit()

            existing_assignment = db.query(Assignment).filter(
                Assignment.school_id == school.id,
                Assignment.teacher_id == teacher.id,
                Assignment.class_id == demo_class.id,
            ).first()
            if not existing_assignment:
                assignment = Assignment(
                    school_id=school.id,
                    teacher_id=teacher.id,
                    class_id=demo_class.id,
                    title="Algebra Homework",
                    description="Practice problems 1-10",
                    due_date=today,
                    file_url="/uploads/algebra_hw.pdf",
                )
                db.add(assignment)
                db.commit()
                db.refresh(assignment)
                db.add(
                    AssignmentSubmission(
                        assignment_id=assignment.id,
                        student_id=student.id,
                        status="submitted",
                    )
                )
                db.commit()
    finally:
        db.close()

@app.on_event("startup")
def on_startup() -> None:
    _seed_demo_data()
