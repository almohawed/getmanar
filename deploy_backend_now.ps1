# نشر Backend المحدث إلى Cloud Run

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "نشر Backend المحدث" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# تعيين المشروع
Write-Host "1. تعيين المشروع..." -ForegroundColor Yellow
gcloud config set project etisak-784d6

# الانتقال إلى مجلد backend_v2
Write-Host ""
Write-Host "2. الانتقال إلى مجلد backend_v2..." -ForegroundColor Yellow
Set-Location backend_v2

# نشر إلى Cloud Run
Write-Host ""
Write-Host "3. نشر إلى Cloud Run..." -ForegroundColor Yellow
gcloud run deploy schedule-solver `
  --source . `
  --region us-central1 `
  --allow-unauthenticated `
  --platform managed `
  --memory 2Gi `
  --cpu 2 `
  --timeout 300

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "✅ تم النشر بنجاح!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Backend URL: https://schedule-solver-979291699789.us-central1.run.app"
Write-Host ""
Write-Host "اختبر الآن: https://etisak-784d6.web.app"
Write-Host ""

Set-Location ..
