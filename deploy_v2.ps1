$Source = "C:\Users\asus\my\almadrasah\build\web"
$Dest = "C:\Users\asus\my\almadrasah\manar01"

Write-Host "Starting deployment from $Source to $Dest"

if (!(Test-Path -Path $Source)) {
    Write-Error "Source directory does not exist!"
    exit 1
}

if (Test-Path -Path $Dest) {
    Write-Host "Cleaning destination..."
    Remove-Item -Path $Dest -Recurse -Force
}

Write-Host "Creating destination directory..."
New-Item -ItemType Directory -Path $Dest -Force | Out-Null

Write-Host "Copying files..."
try {
    Copy-Item -Path "$Source\*" -Destination $Dest -Recurse -Force
    Write-Host "Copy command completed."
} catch {
    Write-Error "Copy failed: $_"
    exit 1
}

$Items = Get-ChildItem -Path $Dest
Write-Host "Destination contains $($Items.Count) items."
if ($Items.Count -eq 0) {
    Write-Error "Destination is empty!"
    exit 1
}

Write-Host "SUCCESS: Files deployed."
