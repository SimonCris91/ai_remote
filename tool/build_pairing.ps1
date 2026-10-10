param(
  [string]$BackendUrl = 'https://remote.aquariusageai.com',
  [string]$Flutter = 'C:\src\flutter\bin\flutter.bat',
  [string]$CodexChannels = 'codex-developer',
  [string]$Output = 'build\app\outputs\flutter-apk\app-debug.apk'
)

$ErrorActionPreference = 'Stop'
if (-not $BackendUrl.StartsWith('https://')) {
  throw 'Il backend pubblico deve usare HTTPS.'
}
& $Flutter build apk --debug `
  --dart-define="AI_REMOTE_BACKEND_URL=$BackendUrl" `
  --dart-define="AI_REMOTE_CODEX_CHANNELS=$CodexChannels"
if ($LASTEXITCODE -ne 0) { throw "Build Flutter fallita ($LASTEXITCODE)." }
Write-Host "APK pronta: $Output"
