@echo off
xcopy build\web manar01 /E /Y > copy_log.txt 2>&1
echo Done
