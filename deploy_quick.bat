@echo off
echo ========================================
echo Quick Deploy - School Add Permission Fix
echo ========================================
echo.

echo Deploying only auth functions...
firebase deploy --only functions:registerNewSchool,functions:createSchoolAdminProvision,functions:deleteSchoolDeep,functions:getUserEmailByIdentity

echo.
echo ========================================
echo Deployment Complete!
echo ========================================
echo.
echo Next steps:
echo 1. Check your role in Firestore (GlobalUsers)
echo 2. Make sure role is 'superAdmin'
echo 3. Logout and login again
echo 4. Try adding a new school
echo.
pause
