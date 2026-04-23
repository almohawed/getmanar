$body = Get-Content -Path "test_request.json" -Raw

$response = Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/v2/generate" -Method Post -Body $body -ContentType "application/json"

Write-Host "========================================" -ForegroundColor Green
Write-Host "  نتيجة التوليد" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Success: $($response.success)" -ForegroundColor $(if($response.success){"Green"}else{"Red"})
Write-Host "Message: $($response.message)"
Write-Host "Solver Status: $($response.diagnostics.solverStatus)"
Write-Host "Total Lessons Placed: $($response.diagnostics.totalLessonsPlaced)"
Write-Host "Execution Time: $($response.diagnostics.executionTimeSeconds) seconds"
Write-Host ""

if ($response.success) {
    Write-Host "✅ الجدول تم توليده بنجاح!" -ForegroundColor Green
    Write-Host ""
    Write-Host "عدد الحصص: $($response.lessons.Count)"
    Write-Host "عدد جداول الفصول: $($response.classSchedules.Count)"
    Write-Host "عدد جداول المعلمين: $($response.teacherSchedules.Count)"
    Write-Host ""
    Write-Host "عينة من الحصص الأولى:" -ForegroundColor Cyan
    $response.lessons | Select-Object -First 5 | ForEach-Object {
        Write-Host "  - $($_.dayName) الحصة $($_.period): $($_.subjectId) (معلم: $($_.teacherId))"
    }
} else {
    Write-Host "❌ فشل التوليد" -ForegroundColor Red
    Write-Host "Issues:" -ForegroundColor Yellow
    $response.precheckReport.issues | ForEach-Object {
        Write-Host "  - $($_.message)"
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
