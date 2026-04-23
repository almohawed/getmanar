"""
تطبيق اختبار بسيط للتأكد من أن الـ container يعمل
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Test App", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {"message": "Test app is working", "status": "ok"}

@app.get("/health")
def health():
    return {"status": "healthy", "version": "1.0.0"}

@app.get("/test")
def test():
    return {
        "message": "All systems operational",
        "features": ["FastAPI", "CORS", "Health Check"]
    }
