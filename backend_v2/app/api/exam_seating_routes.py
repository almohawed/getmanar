from __future__ import annotations

from typing import Any, Dict, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.services.exam_seating_service import ExamSeatingService


router = APIRouter(prefix="/exam-seating", tags=["exam-seating"])
svc = ExamSeatingService()


class CreateSessionRequest(BaseModel):
    schoolId: str = Field(..., min_length=1)
    sessionId: Optional[str] = None
    policyId: Optional[str] = None


class SessionRequest(BaseModel):
    schoolId: str = Field(..., min_length=1)
    sessionId: str = Field(..., min_length=1)


@router.post("/generate-seat-numbers")
def generate_seat_numbers(req: SessionRequest) -> Dict[str, Any]:
    try:
        return svc.generate_seat_numbers(req.schoolId, req.sessionId)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/generate-committees")
def generate_committees(req: SessionRequest) -> Dict[str, Any]:
    try:
        return svc.generate_committees(req.schoolId, req.sessionId)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/assign-seats")
def assign_seats(req: SessionRequest) -> Dict[str, Any]:
    try:
        return svc.assign_seats(req.schoolId, req.sessionId, {})
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/regenerate")
def regenerate(req: SessionRequest) -> Dict[str, Any]:
    try:
        return svc.regenerate(req.schoolId, req.sessionId)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/session/{id}")
def get_session(id: str) -> Dict[str, Any]:
    try:
        return svc.get_session(id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/committee/{id}")
def get_committee(id: str) -> Dict[str, Any]:
    try:
        return svc.get_committee(id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/session")
def create_session(req: CreateSessionRequest) -> Dict[str, Any]:
    try:
        sid = svc.create_session(req.schoolId, req.model_dump())
        return {"sessionId": sid}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

