$Source = "c:\Users\asus\my\almadrasah\build\web"
$Dest = "c:\Users\asus\my\almadrasah\manar01"

Write-Output "Script started"
if (!(Test-Path $Source)) {
    Write-Error "Source missing"
    exit 1
}

if (Test-Path $Dest) {
    Write-Output "Removing Dest"
    Remove-Item $Dest -Recurse -Force
}

Write-Output "Creating Dest"
New-Item -ItemType Directory -Path $Dest -Force

Write-Output "Copying..."
Copy-Item -Path "$Source\*" -Destination $Dest -Recurse -Force

Write-Output "Done"
Get-ChildItem $Dest
