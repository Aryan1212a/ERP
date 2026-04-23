#!/usr/bin/env python3
"""
Delete all data and reseed the database with valid data.
"""

import sys
from pathlib import Path

# Add the app directory to the path
sys.path.insert(0, str(Path(__file__).parent / "app"))

from sqlalchemy import create_engine, text
from app.core.config import settings
from app.db.session import Base

DATABASE_URL = settings.DATABASE_URL
print(f"Using database: {DATABASE_URL}\n")

try:
    engine = create_engine(DATABASE_URL)
    print("Testing connection...")
    with engine.connect() as conn:
        result = conn.execute(text("SELECT 1"))
        print("✓ Database connection successful\n")
    
    print("Dropping all tables...")
    Base.metadata.drop_all(bind=engine)
    print("✓ All tables dropped\n")
    
    print("Creating all tables...")
    Base.metadata.create_all(bind=engine)
    print("✓ All tables created\n")
    
    print("Database reset successfully!")
    print("Now run: python seed.py")
    
except Exception as e:
    print(f"✗ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
