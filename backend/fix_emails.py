#!/usr/bin/env python3
"""
Fix invalid email addresses in the PostgreSQL database.
"""

import sys
from pathlib import Path

# Add the app directory to the path
sys.path.insert(0, str(Path(__file__).parent / "app"))

from sqlalchemy import create_engine, text
from app.core.config import describe_database_url, settings

DATABASE_URL = settings.DATABASE_URL
print(f"Using database: {describe_database_url(DATABASE_URL)}")

try:
    engine = create_engine(DATABASE_URL)
    print("Testing connection...")
    with engine.connect() as conn:
        result = conn.execute(text("SELECT 1"))
        print("✓ Database connection successful\n")
        
        # Find invalid emails
        result = conn.execute(text('''
            SELECT id, full_name, email FROM users 
            WHERE email LIKE '%.@%' OR email LIKE '%..%'
            ORDER BY id
        '''))
        
        invalid_emails = result.fetchall()
        print(f"Found {len(invalid_emails)} users with invalid emails\n")
        
        for user_id, full_name, email in invalid_emails:
            # Generate new email from full_name
            parts = full_name.split()
            
            # Filter out titles (Dr., Prof., Mr., Ms., etc.)
            titles = {'Dr.', 'Prof.', 'Mr.', 'Ms.', 'Mr', 'Ms', 'Dr', 'Prof'}
            name_parts = [p.rstrip('.') for p in parts if p.rstrip('.') not in titles and p.rstrip('.').strip()]
            
            if len(name_parts) >= 2:
                first_name = name_parts[0].lower()
                last_name = name_parts[-1].lower()
            elif len(name_parts) == 1:
                first_name = name_parts[0].lower()
                last_name = 'user'
            else:
                first_name = 'user'
                last_name = str(user_id)
            
            # Ensure no periods at the end
            first_name = first_name.rstrip('.')
            last_name = last_name.rstrip('.')
            
            new_email = f"{first_name}{last_name}{user_id}@school.edu"
            
            print(f"Fixing user {user_id}:")
            print(f"  Name: {full_name}")
            print(f"  Old email: {email}")
            print(f"  New email: {new_email}")
            
            # Update the email
            with engine.begin() as connection:
                connection.execute(text('''
                    UPDATE users SET email = :new_email 
                    WHERE id = :user_id
                '''), {"new_email": new_email, "user_id": user_id})
            print("  ✓ Fixed\n")
        
        if invalid_emails:
            print("All emails have been fixed!")
        else:
            print("No invalid emails found!")
            
except Exception as e:
    print(f"✗ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
