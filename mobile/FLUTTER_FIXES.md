# Flutter App - Backend Connection & Hero Fix

## Issues Fixed

### ✅ Hero Widget Conflicts
Fixed by adding unique `heroTag` to FloatingActionButtons in:
- `admin_users_screen.dart` → `'admin_users_fab'`
- `admin_classes_screen.dart` → `'admin_classes_fab'`
- `attendance_screen.dart` → `'attendance_fab'`
- `notices_screen.dart` → `'notices_fab'`

These screens are used in `IndexedStack`, which keeps all widgets in the tree simultaneously. Without unique tags, Hero animations conflicted.

---

## ⚠️ Login Timeout Issue

### Problem
The Flutter app times out when trying to login because the backend API is not running.

### Configuration
The app looks for the backend at:
- **Linux/Desktop**: `http://127.0.0.1:8000`
- **Android**: `http://10.0.2.2:8000`

See: `lib/services/service_locator.dart`

### Solution: Start the Backend

#### Step 1: Open a terminal in the backend folder
```bash
cd /home/aryan/ERP/backend
```

#### Step 2: Activate the virtual environment (if needed)
```bash
source venv/bin/activate
# or use the full path:
./venv/bin/python -m uvicorn app.main:app --reload
```

#### Step 3: Start the FastAPI server
```bash
./venv/bin/python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete
```

#### Step 4: Test the connection
```bash
# In another terminal
curl http://127.0.0.1:8000/api/v1/dashboard
# This should return an error (no auth), but proves the connection works
```

---

## Testing the Login

### Test Credentials

After seeding the database with valid emails, use:

**Admin:**
- Email: `admin@school.edu`
- Password: `admin123`

**Student Example:**
- Email: `aradhyaghosh52@school.edu`
- Password: (from seeding output)

**Teacher Example:**
- Email: `rajeshsharma52@school.edu`
- Password: (from seeding output)

### Steps to Test

1. **Start Backend** (see above steps)
2. **Run Flutter App**:
   ```bash
   cd /home/aryan/ERP/mobile
   flutter run
   ```
3. **Enter credentials** and tap Login
4. **Should succeed** if backend is running

---

## Troubleshooting

### Still getting timeout?

Check if backend is accessible:
```bash
# From your machine
curl -X GET "http://127.0.0.1:8000/api/v1/dashboard" \
  -H "Authorization: Bearer fake_token"

# Should return 401 (unauthorized) not a timeout
```

### Backend connection errors?

Check the `.env` file in the backend:
```bash
cat /home/aryan/ERP/backend/.env
# Should show: DATABASE_URL=postgresql+psycopg://...
```

If using PostgreSQL, make sure it's running:
```bash
sudo systemctl start postgresql
```

Or switch to SQLite in `.env`:
```
DATABASE_URL=sqlite:///./school_erp.db
```

---

## What's Next

1. ✅ Start the backend
2. ✅ Run Flutter app
3. ✅ Login should work
4. ✅ Hero animation errors are fixed - navigation should be smooth
