from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.db.session import Base, get_db

SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
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

def test_register_and_login():
    r = client.post("/api/v1/auth/register", json={
        "school_id": 1,
        "email": "user@example.com",
        "full_name": "Test User",
        "password": "secret"
    })
    assert r.status_code == 200
    r = client.post("/api/v1/auth/login", json={
        "email": "user@example.com",
        "password": "secret"
    })
    assert r.status_code == 200
    assert "access_token" in r.json()
