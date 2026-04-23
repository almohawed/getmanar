@echo off
echo Starting Copy... > c:\Users\asus\my\almadrasah\copy_status.txt
if not exist "c:\Users\asus\my\almadrasah\manar01" mkdir "c:\Users\asus\my\almadrasah\manar01"
C:\Windows\System32\xcopy.exe "c:\Users\asus\my\almadrasah\build\web" "c:\Users\asus\my\almadrasah\manar01" /E /I /H /Y >> c:\Users\asus\my\almadrasah\copy_status.txt 2>&1
echo Done >> c:\Users\asus\my\almadrasah\copy_status.txt
