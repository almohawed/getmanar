if (!(Test-Path "manar01")) { mkdir "manar01" }
Copy-Item "build\web\*" "manar01" -Recurse -Force
