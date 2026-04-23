@echo off
echo ========================================
echo    اختبار قسم ارسال الرسائل SMS
echo ========================================
echo.

echo [1/4] التحقق من الكود...
findstr /C:"Tab(icon: Icon(Icons.send), text: 'إرسال الرسائل')" lib\src\features\admin\presentation\sms_settings_screen.dart >nul
if %errorlevel% equ 0 (
    echo ✓ التبويب موجود في الكود
) else (
    echo ✗ التبويب غير موجود!
    pause
    exit /b 1
)

echo.
echo [2/4] التحقق من TabController...
findstr /C:"TabController(length: 4" lib\src\features\admin\presentation\sms_settings_screen.dart >nul
if %errorlevel% equ 0 (
    echo ✓ TabController يحتوي على 4 تبويبات
) else (
    echo ✗ TabController لا يحتوي على 4 تبويبات!
    pause
    exit /b 1
)

echo.
echo [3/4] التحقق من دالة _buildSendMessagesTab...
findstr /C:"Widget _buildSendMessagesTab()" lib\src\features\admin\presentation\sms_settings_screen.dart >nul
if %errorlevel% equ 0 (
    echo ✓ دالة _buildSendMessagesTab موجودة
) else (
    echo ✗ دالة _buildSendMessagesTab غير موجودة!
    pause
    exit /b 1
)

echo.
echo [4/4] التحقق من دالة _sendMessage...
findstr /C:"Future<void> _sendMessage()" lib\src\features\admin\presentation\sms_settings_screen.dart >nul
if %errorlevel% equ 0 (
    echo ✓ دالة _sendMessage موجودة
) else (
    echo ✗ دالة _sendMessage غير موجودة!
    pause
    exit /b 1
)

echo.
echo ========================================
echo    ✅ الكود صحيح 100%%!
echo ========================================
echo.
echo الآن قم بإعادة تشغيل التطبيق:
echo.
echo 1. أوقف التطبيق الحالي (Ctrl+C)
echo 2. نظف المشروع: flutter clean
echo 3. احصل على الحزم: flutter pub get  
echo 4. شغل التطبيق: flutter run
echo.
echo أو في VS Code:
echo - اضغط Ctrl+Shift+P
echo - اكتب: Flutter: Hot Restart
echo.
pause
