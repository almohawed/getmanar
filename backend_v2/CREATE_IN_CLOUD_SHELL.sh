#!/bin/bash

# سكريبت لإنشاء Backend V2 في Cloud Shell من الصفر

echo "========================================="
echo "إنشاء Backend V2 في Cloud Shell"
echo "========================================="

# تعيين المشروع
gcloud config set project etisak-784d6

# إنشاء البنية
mkdir -p backend_v2/app/{api,models,services}
cd backend_v2

# إنشاء requirements.txt
cat > requirements.txt << 'EOF'
fastapi==0.115.5
uvicorn[standard]==0.32.1
gunicorn==23.0.0
ortools==9.15.6755
pydantic==2.9.2
pydantic-settings==2.5.2
firebase-admin==6.5.0
EOF

# إنشاء Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

ENV PORT=8080
EXPOSE 8080

CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 app.main:app --worker-class uvicorn.workers.UvicornWorker
EOF

# إنشاء __init__.py files
touch app/__init__.py
touch app/api/__init__.py
touch app/models/__init__.py
touch app/services/__init__.py

echo "✅ تم إنشاء البنية الأساسية"
echo ""
echo "الآن استخدم Cloud Shell Editor لإنشاء الملفات التالية:"
echo "- app/main.py"
echo "- app/config.py"
echo "- app/api/routes.py"
echo "- app/models/school.py"
echo "- app/models/schedule.py"
echo "- app/services/precheck_service.py"
echo "- app/services/solver_service.py"
echo "- app/services/firebase_service.py"
echo ""
echo "أو ارفع المجلد كاملاً من جهازك"
