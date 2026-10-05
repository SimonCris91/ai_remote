param(
  [string]$BackendUrl = 'https://remote.aquariusageai.com',
  [string]$Flutter = 'C:\src\flutter\bin\flutter.bat',
  [string]$Output = 'build\app\outputs\flutter-apk\app-debug.apk'
)

$ErrorActionPreference = 'Stop'
if (-not $BackendUrl.StartsWith('https://')) {
  throw 'Il backend pubblico deve usare HTTPS.'
}
& $Flutter build apk --debug `
  --dart-define="AI_REMOTE_BACKEND_URL=$BackendUrl"
if ($LASTEXITCODE -ne 0) { throw "Build Flutter fallita ($LASTEXITCODE)." }
Write-Host "APK pronta: $Output"
