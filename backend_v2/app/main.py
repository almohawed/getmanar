from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router
from app.api.exam_seating_routes import router as exam_seating_router
from app.config import settings

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
)

origins = [o.strip() for o in settings.cors_origins.split(",")] if settings.cors_origins else ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)
app.include_router(exam_seating_router)

@app.get("/")
def root():
    return {
        "message": "School Schedule Solver V2 is running",
        "health": "/api/v2/health",
        "precheck": "/api/v2/precheck",
        "generate": "/api/v2/generate",
    }
