# استخدام Python 3.11
FROM python:3.11-slim

# تعيين مجلد العمل
WORKDIR /app

# تثبيت dependencies للنظام
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# نسخ requirements
COPY requirements.txt .

# تثبيت المكتبات
RUN pip install --no-cache-dir -r requirements.txt

# نسخ الكود
COPY . .

# المنفذ
EXPOSE 8080

# تشغيل التطبيق
CMD ["gunicorn", "-w", "1", "-k", "uvicorn.workers.UvicornWorker", "app.main:app", "--bind", "0.0.0.0:8080"]
