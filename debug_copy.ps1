$src = "c:\Users\asus\my\almadrasah\build\app\outputs\apk\release\app-release.apk"
$dst = "c:\Users\asus\my\almadrasah\manar01\app-release.apk"
$log = "c:\Users\asus\my\almadrasah\ps_log.txt"

"Starting copy..." | Out-File $log -Encoding utf8

if (Test-Path $src) {
    "Source exists" | Out-File $log -Append -Encoding utf8
    Copy-Item -Path $src -Destination $dst -Force -Verbose 4>> $log
    
    if (Test-Path $dst) {
        "Destination exists" | Out-File $log -Append -Encoding utf8
    } else {
        "Destination MISSING" | Out-File $log -Append -Encoding utf8
    }
} else {
    "Source MISSING" | Out-File $log -Append -Encoding utf8
}
