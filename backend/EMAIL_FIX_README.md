# Email Validation Fix - Instructions

## Problem
The seed script was generating invalid email addresses for teachers like `rajesh.dr.@school.edu` (period immediately before @), which violates email format validation.

## Solution

I've fixed the seed script and created utility scripts to clean up your database. Choose one of the two approaches below:

### Option 1: Fix Existing Emails (Faster)

If you want to keep your current data and just fix the invalid emails:

```bash
cd /home/aryan/ERP/backend
./venv/bin/python fix_emails.py
```

This will:
- Find all users with invalid emails
- Generate valid replacement emails
- Update the database

### Option 2: Reset and Reseed (Cleaner)

If you want to start fresh with valid data:

```bash
cd /home/aryan/ERP/backend

# Step 1: Reset the database
./venv/bin/python reset_db.py

# Step 2: Reseed with corrected data
./venv/bin/python seed.py
```

This will:
- Drop all tables and recreate them
- Populate with 54 users (33 students + 20 teachers + 1 admin)
- All with valid email addresses

## What Was Fixed

### In the seed.py script:

1. **Email generation**: Now removes trailing periods from names and doesn't add periods between names
   - Before: `rajesh.dr.@school.edu` ❌
   - After: `rajeshghosh52@school.edu` ✓

2. **Teacher names**: Now includes proper last names instead of titles as last names
   - Before: "Dr. Rajesh" → email: rajesh.dr.@...
   - After: "Dr. Rajesh Sharma" → email: rajeshsharma52@...

3. **Username generation**: Also cleaned up to avoid invalid characters

## After Running Fix/Reseed

Restart your FastAPI backend and the email validation errors should be gone!

```bash
cd /home/aryan/ERP/backend
./venv/bin/python -m uvicorn app.main:app --reload
```
