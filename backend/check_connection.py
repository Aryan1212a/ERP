#!/usr/bin/env python3
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent / "app"))

try:
    from app.core.config import describe_database_url, settings
    print(f"Database configured: {describe_database_url(settings.DATABASE_URL)}")
    
    from sqlalchemy import create_engine, text
    print("Creating engine...")
    engine = create_engine(settings.DATABASE_URL)
    print("Connecting to database...")
    with engine.connect() as conn:
        print("Connected!")
        result = conn.execute(text("SELECT COUNT(*) FROM users"))
        count = result.fetchone()[0]
        print(f"Total users: {count}")
        
        result = conn.execute(text("SELECT email FROM users WHERE email LIKE '%.@%' LIMIT 5"))
        invalid = result.fetchall()
        print(f"Invalid emails found: {len(invalid)}")
        for email in invalid:
            print(f"  - {email[0]}")
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
