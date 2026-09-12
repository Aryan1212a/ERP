#!/usr/bin/env python3
"""
Seed script for ERP backend database.
Creates a school and populates it with users (students and teachers).
"""

import random
import string
import sys
from pathlib import Path

# Add the app directory to the path
sys.path.insert(0, str(Path(__file__).parent / "app"))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models.models import School, User, Class, Base
from app.core.security import hash_password
from app.core.config import describe_database_url, settings

# Use the database URL from settings
DATABASE_URL = settings.DATABASE_URL
print(f"Using database: {describe_database_url(DATABASE_URL)}")
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False} if "sqlite" in DATABASE_URL else {})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create tables
Base.metadata.create_all(bind=engine)
print("Database tables created/ensured")

# Sample data
FIRST_NAMES = [
    "Aarav", "Vihaan", "Vivaan", "Ananya", "Diya", "Saanvi", "Pari", "Anika",
    "Navya", "Aadhya", "Aaradhya", "Siya", "Aanya", "Pihu", "Riya", "Ira",
    "Sahana", "Anvi", "Kiara", "Eva", "Myra", "Sara", "Zara", "Amaira",
    "Aadhira", "Advika", "Ahana", "Amaya", "Anaya", "Aradhya", "Avni", "Bhoomi",
    "Charvi", "Devanshi", "Divya", "Esha", "Gauri", "Hiya", "Isha", "Jiya",
    "Kavya", "Khushi", "Kiara", "Lavanya", "Mahika", "Manvi", "Mira", "Nandini",
    "Neha", "Nisha", "Pavithra", "Prisha", "Rhea", "Ridhi", "Riya", "Saanvi",
    "Samantha", "Sara", "Shreya", "Sia", "Simran", "Sneha", "Soha", "Sonia",
    "Tanya", "Tara", "Trisha", "Vani", "Veda", "Vidya", "Yashvi", "Zoya"
]

LAST_NAMES = [
    "Sharma", "Verma", "Gupta", "Singh", "Kumar", "Patel", "Jain", "Agarwal",
    "Reddy", "Nair", "Chatterjee", "Banerjee", "Das", "Mukherjee", "Saha",
    "Roy", "Chakraborty", "Ghosh", "Dutta", "Sengupta", "Bose", "Mitra",
    "Chaudhuri", "Ganguly", "Bhattacharjee", "Sarkar", "Pal", "Debnath",
    "Mondal", "Paul", "Karmakar", "Naskar", "Biswas", "Chakrabarti", "Majumdar"
]

TEACHER_FIRST_NAMES = [
    "Dr. Rajesh", "Prof. Priya", "Mr. Amit", "Ms. Sunita", "Dr. Vikram",
    "Prof. Meera", "Mr. Sanjay", "Ms. Kavita", "Dr. Arjun", "Prof. Anjali",
    "Mr. Rohit", "Ms. Neha", "Dr. Karan", "Prof. Pooja", "Mr. Manoj",
    "Ms. Ritu", "Dr. Sameer", "Prof. Divya", "Mr. Naveen", "Ms. Swati"
]

CLASS_NAMES = [
    "Grade 1", "Grade 2", "Grade 3", "Grade 4", "Grade 5", "Grade 6",
    "Grade 7", "Grade 8", "Grade 9", "Grade 10", "Grade 11", "Grade 12"
]

def generate_email(first_name: str, last_name: str, role: str, counter: int = None) -> str:
    """Generate a unique email address."""
    # Clean up names (remove trailing periods)
    first_name = first_name.rstrip('.')
    last_name = last_name.rstrip('.')
    
    base = f"{first_name.lower()}{last_name.lower()}"
    if counter:
        base += f"{counter}"
    base += "@school.edu"
    return base

def generate_username(first_name: str, last_name: str, role: str, counter: int = None) -> str:
    """Generate a unique username."""
    # Clean up names (remove trailing periods)
    first_name = first_name.rstrip('.')
    last_name = last_name.rstrip('.')
    
    base = f"{first_name.lower()}{last_name.lower()}"
    if counter:
        base += f"{counter}"
    if role == "teacher":
        base = f"teacher_{base}"
    return base

def generate_password() -> str:
    """Generate a random password."""
    chars = string.ascii_letters + string.digits
    return ''.join(random.choice(chars) for _ in range(8))

def seed_database():
    """Seed the database with sample data."""
    db: Session = SessionLocal()
    try:
        # Check if school already exists
        school = db.query(School).first()
        if not school:
            school = School(name="Demo School")
            db.add(school)
            db.commit()
            db.refresh(school)
            print(f"Created school: {school.name}")
        else:
            print(f"Using existing school: {school.name}")

        # Create classes
        classes = []
        for class_name in CLASS_NAMES:
            class_obj = db.query(Class).filter_by(name=class_name, school_id=school.id).first()
            if not class_obj:
                class_obj = Class(name=class_name, school_id=school.id)
                db.add(class_obj)
                db.commit()
                db.refresh(class_obj)
                print(f"Created class: {class_obj.name}")
            classes.append(class_obj)

        # Create admin user
        admin = db.query(User).filter_by(email="admin@school.edu").first()
        if not admin:
            admin = User(
                school_id=school.id,
                email="admin@school.edu",
                full_name="School Administrator",
                username="admin",
                password_hash=hash_password("admin123"),
                role="admin",
                must_change_password=False
            )
            db.add(admin)
            db.commit()
            db.refresh(admin)
            print(f"Created admin user: {admin.email}")

        # Create teachers
        teachers = []
        for i, teacher_name in enumerate(TEACHER_FIRST_NAMES):
            # Extract title and first name, then add a random last name
            parts = teacher_name.split()
            title = parts[0] if len(parts) > 0 else ""  # Dr., Prof., Mr., Ms.
            first_name = parts[1] if len(parts) > 1 else parts[0]
            last_name = random.choice(LAST_NAMES)
            
            # Store display name with title
            display_name = f"{title} {first_name} {last_name}"

            email = generate_email(first_name, last_name, "teacher", i+1 if i > 0 else None)
            username = generate_username(first_name, last_name, "teacher", i+1 if i > 0 else None)

            teacher = db.query(User).filter_by(email=email).first()
            if not teacher:
                password = generate_password()
                teacher = User(
                    school_id=school.id,
                    email=email,
                    full_name=display_name,
                    username=username,
                    password_hash=hash_password(password),
                    role="teacher",
                    must_change_password=True
                )
                db.add(teacher)
                db.commit()
                db.refresh(teacher)
                teachers.append(teacher)
                print(f"Created teacher: {teacher.full_name} ({teacher.email}) - temporary password generated")
            else:
                teachers.append(teacher)

        # Assign teachers as class teachers
        for i, class_obj in enumerate(classes):
            if i < len(teachers):
                class_obj.class_teacher_id = teachers[i].id
                teachers[i].class_id = class_obj.id
                db.commit()
                print(f"Assigned {teachers[i].full_name} as teacher for {class_obj.name}")

        # Create students
        students_created = 0
        target_students = 33

        while students_created < target_students:
            first_name = random.choice(FIRST_NAMES)
            last_name = random.choice(LAST_NAMES)
            email = generate_email(first_name, last_name, "student", students_created+1 if students_created > 0 else None)
            username = generate_username(first_name, last_name, "student", students_created+1 if students_created > 0 else None)

            # Check if user already exists
            existing = db.query(User).filter_by(email=email).first()
            if existing:
                continue

            # Assign to a random class
            class_id = random.choice(classes).id if classes else None

            password = generate_password()
            student = User(
                school_id=school.id,
                email=email,
                full_name=f"{first_name} {last_name}",
                username=username,
                password_hash=hash_password(password),
                role="student",
                class_id=class_id,
                must_change_password=True
            )
            db.add(student)
            db.commit()
            db.refresh(student)
            students_created += 1
            print(f"Created student: {student.full_name} ({student.email}) - temporary password generated - Class: {class_id}")

        print(f"\nSeeding completed!")
        print(f"Total users created: {len(teachers) + students_created + 1}")  # +1 for admin
        print(f"Teachers: {len(teachers)}")
        print(f"Students: {students_created}")
        print(f"Admin: 1")

    except Exception as e:
        db.rollback()
        print(f"Error during seeding: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    seed_database()
