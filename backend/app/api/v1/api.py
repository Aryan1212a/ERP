from fastapi import APIRouter

from app.api.v1.routes import admin, assignments, attendance, auth, fees, notices, student, teacher, timetable

api_router = APIRouter()

api_router.include_router(auth.profile_router)
api_router.include_router(auth.router)
api_router.include_router(admin.admin_router)
api_router.include_router(admin.router)
api_router.include_router(teacher.router)
api_router.include_router(student.router)
api_router.include_router(attendance.router)
api_router.include_router(attendance.teacher_router)
api_router.include_router(fees.router)
api_router.include_router(timetable.router)
api_router.include_router(notices.router)
api_router.include_router(notices.student_router)
api_router.include_router(assignments.router)
