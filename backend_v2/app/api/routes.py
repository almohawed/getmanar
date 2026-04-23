from fastapi import APIRouter

from app.config import settings
from app.models.school import GenerationRequest
from app.services.precheck_service import run_precheck
from app.services.solver_service import generate_schedule

router = APIRouter(prefix="/api/v2", tags=["schedule-v2"])

@router.get("/health")
def health():
    return {
        "status": "healthy",
        "name": settings.app_name,
        "version": settings.app_version,
    }

@router.post("/precheck")
def precheck(req: GenerationRequest):
    return run_precheck(req)

@router.post("/generate")
def generate(req: GenerationRequest):
    return generate_schedule(req)
