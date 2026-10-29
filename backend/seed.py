#!/usr/bin/env python3
"""Create a small, repeatable college demo dataset."""

from datetime import date

from app.core.config import settings
from app.core.security import hash_password
from app.db.session import Base
from app.models.models import (
    AcademicTerm, Course, CourseOffering, Department, Enrollment, Program,
    School, User, Class,
)
from sqlalchemy import create_engine
from sqlalchemy.orm import Session


def seed_database() -> None:
    engine = create_engine(settings.DATABASE_URL)
    Base.metadata.create_all(bind=engine)

    with Session(engine) as db:
        college = db.query(School).filter_by(name="Demo College").first()
        if college is None:
            college = School(name="Demo College")
            db.add(college)
            db.flush()

        department_data = [("Computer Science", "CS"), ("Business Administration", "BUS")]
        departments = {}
        for name, code in department_data:
            item = db.query(Department).filter_by(school_id=college.id, code=code).first()
            if item is None:
                item = Department(school_id=college.id, name=name, code=code)
                db.add(item)
                db.flush()
            departments[code] = item

        program_data = [("BSc Computer Science", "BSCS", "CS"), ("BBA", "BBA", "BUS")]
        for name, code, department_code in program_data:
            if not db.query(Program).filter_by(school_id=college.id, code=code).first():
                db.add(Program(school_id=college.id, department_id=departments[department_code].id,
                               name=name, code=code, duration_years=4))

        course_data = [("CS101", "Programming Fundamentals", "CS"),
                       ("CS201", "Database Systems", "CS"),
                       ("BUS101", "Principles of Management", "BUS")]
        courses = {}
        for code, title, department_code in course_data:
            item = db.query(Course).filter_by(school_id=college.id, code=code).first()
            if item is None:
                item = Course(school_id=college.id, department_id=departments[department_code].id,
                              code=code, title=title, credits=3)
                db.add(item)
                db.flush()
            courses[code] = item

        term = db.query(AcademicTerm).filter_by(school_id=college.id, name="Fall 2026").first()
        if term is None:
            term = AcademicTerm(school_id=college.id, name="Fall 2026",
                                starts_on=date(2026, 8, 1), ends_on=date(2026, 12, 20))
            db.add(term)
            db.flush()

        # The legacy class endpoints remain available during the API transition.
        cohort = db.query(Class).filter_by(school_id=college.id, name="Year 1 Cohort A").first()
        if cohort is None:
            cohort = Class(school_id=college.id, name="Year 1 Cohort A")
            db.add(cohort)
            db.flush()

        admin = db.query(User).filter_by(email="admin@college.edu").first()
        if admin is None:
            db.add(User(school_id=college.id, email="admin@college.edu", full_name="College Administrator",
                        username="admin", password_hash=hash_password("admin123"), role="admin",
                        must_change_password=False))

        faculty = db.query(User).filter_by(email="faculty@college.edu").first()
        if faculty is None:
            faculty = User(school_id=college.id, email="faculty@college.edu", full_name="Dr. Asha Rao",
                           username="faculty_asha", password_hash=hash_password("faculty123"),
                           role="teacher", class_id=cohort.id, must_change_password=False)
            db.add(faculty)
            db.flush()
        cohort.class_teacher_id = faculty.id

        student = db.query(User).filter_by(email="student@college.edu").first()
        if student is None:
            student = User(school_id=college.id, email="student@college.edu", full_name="Aarav Sharma",
                           username="aarav.sharma", password_hash=hash_password("student123"),
                           role="student", class_id=cohort.id, must_change_password=False)
            db.add(student)
            db.flush()

        for code, course in courses.items():
            offering = db.query(CourseOffering).filter_by(
                school_id=college.id, course_id=course.id, term_id=term.id, section="A"
            ).first()
            if offering is None:
                offering = CourseOffering(school_id=college.id, course_id=course.id, term_id=term.id,
                                          faculty_id=faculty.id, section="A", room="Block A")
                db.add(offering)
                db.flush()
            if not db.query(Enrollment).filter_by(offering_id=offering.id, student_id=student.id).first():
                db.add(Enrollment(offering_id=offering.id, student_id=student.id))

        db.commit()
    print(f"Seeded college data in {settings.DATABASE_URL}")
    print("Demo logins: admin@college.edu / admin123, faculty@college.edu / faculty123, student@college.edu / student123")


if __name__ == "__main__":
    seed_database()
