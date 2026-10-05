param(
  [string]$GoogleServerClientId = $env:GOOGLE_SERVER_CLIENT_ID
)

$ErrorActionPreference = 'Stop'
$backendUrl = 'https://remote.aquariusageai.com'

if ([string]::IsNullOrWhiteSpace($GoogleServerClientId)) {
  throw 'Manca GOOGLE_SERVER_CLIENT_ID. È un client ID pubblico, non una chiave segreta.'
}

$flutter = 'C:\src\flutter\bin\flutter.bat'
& $flutter build apk `
  --dart-define="AI_REMOTE_BACKEND_URL=$backendUrl" `
  --dart-define="GOOGLE_SERVER_CLIENT_ID=$GoogleServerClientId"
