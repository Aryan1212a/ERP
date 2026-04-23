#!/usr/bin/env python3
"""
Verify the seeded database data.
"""

import sys
from pathlib import Path

# Add the app directory to the path
sys.path.insert(0, str(Path(__file__).parent / "app"))

from sqlalchemy import create_engine, text

# Use SQLite for verification
DATABASE_URL = "sqlite:///./school_erp.db"
engine = create_engine(DATABASE_URL)

def verify_data():
    """Verify the seeded data."""
    with engine.connect() as conn:
        # Count users by role
        result = conn.execute(text('SELECT role, COUNT(*) as count FROM users GROUP BY role'))
        print('User counts by role:')
        for row in result:
            print(f'  {row[0]}: {row[1]}')

        # Total users
        result = conn.execute(text('SELECT COUNT(*) as total FROM users'))
        total = result.fetchone()[0]
        print(f'Total users: {total}')

        # Classes
        result = conn.execute(text('SELECT COUNT(*) as classes FROM classes'))
        classes = result.fetchone()[0]
        print(f'Total classes: {classes}')

        # School
        result = conn.execute(text('SELECT name FROM schools LIMIT 1'))
        school = result.fetchone()
        if school:
            print(f'School: {school[0]}')

        # Sample users
        result = conn.execute(text('SELECT full_name, email, role FROM users LIMIT 5'))
        print('\nSample users:')
        for row in result:
            print(f'  {row[0]} ({row[1]}) - {row[2]}')

if __name__ == "__main__":
    verify_data()