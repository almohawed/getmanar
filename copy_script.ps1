$source = "C:\Users\asus\my\almadrasah\build\web"
$dest = "C:\Users\asus\my\almadrasah\manar01"
Write-Host "Copying from $source to $dest"
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest }
Copy-Item -Path "$source\*" -Destination $dest -Recurse -Force
Get-ChildItem $dest | Out-File "copy_result_ps1.txt"
Write-Host "Copy done"
