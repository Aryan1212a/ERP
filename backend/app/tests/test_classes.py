from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.db.session import Base, get_db
from app.models.models import User, School
from app.core.security import hash_password, create_access_token

SQLALCHEMY_DATABASE_URL = "sqlite:///./test_classes.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base.metadata.create_all(bind=engine)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)

def _admin_token(db):
    school = School(name="Test School")
    db.add(school)
    db.commit()
    db.refresh(school)
    admin = User(
        school_id=school.id,
        email="admin@example.com",
        full_name="Admin",
        password_hash=hash_password("secret"),
        role="admin",
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)
    return create_access_token({"sub": admin.id, "school_id": admin.school_id})

def test_class_crud():
    db = TestingSessionLocal()
    try:
        token = _admin_token(db)
    finally:
        db.close()
    headers = {"Authorization": f"Bearer {token}"}

    r = client.post("/api/v1/classes", json={"name": "Grade 1"}, headers=headers)
    assert r.status_code == 200
    class_id = r.json()["id"]

    r = client.get("/api/v1/classes", headers=headers)
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = client.put(f"/api/v1/classes/{class_id}", json={"name": "Grade 1A"}, headers=headers)
    assert r.status_code == 200
    assert r.json()["name"] == "Grade 1A"

    r = client.delete(f"/api/v1/classes/{class_id}", headers=headers)
    assert r.status_code == 200
