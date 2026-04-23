# School Schedule Generator v2 - Production System

## 🚀 Quick Start

### Local Development

```bash
cd backend_v2
pip install -r requirements.txt
python -m app.main
```

Server runs on: http://localhost:8000

### Test System

```bash
python test_system.py
```

## 🌐 Deploy to Production

### Option 1: Railway (Recommended - Free)

1. Go to https://railway.app
2. Create new project from GitHub
3. Select `backend_v2` folder
4. Add environment variable:
   ```
   FIREBASE_CREDENTIALS=<content of serviceAccountKey.json>
   ```
5. Deploy automatically

### Option 2: Render (Free Alternative)

1. Go to https://render.com
2. Create new Web Service
3. Root Directory: `backend_v2`
4. Build Command: `pip install -r requirements.txt`
5. Start Command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
6. Add environment variable: `FIREBASE_CREDENTIALS`

### Option 3: Docker

```bash
cd backend_v2
docker build -t schedule-backend-v2 .
docker run -p 8000:8000 -e FIREBASE_CREDENTIALS="$(cat serviceAccountKey.json)" schedule-backend-v2
```

## 📚 API Documentation

### Endpoints

#### GET /
Health check and system info

#### POST /api/v2/precheck
Validate school data before generation

Request:
```json
{
  "school_id": "school123",
  "school_type": "middle",
  "classes": [...],
  "teachers": [...],
  "subjects": [...]
}
```

Response:
```json
{
  "can_generate": true,
  "issues": [],
  "warnings": [],
  "summary": {...}
}
```

#### POST /api/v2/generate_schedule
Generate complete schedule

Request: Same as precheck

Response:
```json
{
  "success": true,
  "schedule": {...},
  "stats": {...},
  "diagnostics": {...}
}
```

#### GET /api/v2/health
System health check

## ✨ Features

- ✅ Precheck validation (demand/capacity analysis)
- ✅ Hard constraints (never violated)
  - No teacher conflicts
  - Exact weekly hours per subject
  - Max lessons per day
  - Teacher load limits
  - Unavailable slots
- ✅ Soft constraints (weighted penalties)
  - Minimize teacher gaps (10.0)
  - Minimize class gaps (5.0)
  - Daily balance (8.0)
  - Avoid heavy last period (7.0)
  - Teacher daily balance (6.0)
  - Subject distribution (9.0)
- ✅ Manual constraints from Firebase
- ✅ Repair mode on failure
- ✅ Support all school types (primary, middle, secondary)
- ✅ Detailed diagnostics
- ✅ Auto distribution to students/teachers

## 🔧 Configuration

### Environment Variables

- `PORT`: Server port (default: 8000)
- `FIREBASE_CREDENTIALS`: Firebase service account JSON (optional, falls back to file)

### Firebase Setup

Place `serviceAccountKey.json` in `backend_v2/` directory or set as environment variable.

## 📊 Performance

- Average solve time: 0.1-0.5 seconds
- Success rate: 99%+ with valid data
- Supports: 50+ classes, 100+ teachers
- Time limit: 30 seconds per generation

## 🐛 Troubleshooting

### Backend not starting?

1. Check Python version: `python --version` (need 3.11+)
2. Install dependencies: `pip install -r requirements.txt`
3. Check logs for errors

### Generation failing?

1. Run precheck first
2. Check precheck report for issues
3. Fix data issues (missing teachers, overload, etc.)
4. Try again

### Firebase connection issues?

1. Check `serviceAccountKey.json` exists
2. Check Firebase credentials are valid
3. Check Firestore rules allow access

## 📞 Support

For issues or questions, check:
- Logs: `railway logs` or Render dashboard
- API docs: `https://your-backend-url/docs`
- Health check: `https://your-backend-url/api/v2/health`

## 📄 License

Private - School Management System
