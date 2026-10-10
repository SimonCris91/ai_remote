$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$env:CODEX_HOME = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
  Join-Path $env:USERPROFILE '.codex'
} else {
  $env:CODEX_HOME
}

$env:CODEX_APP_SERVER_ENABLED = 'true'
$env:CODEX_WORKSPACE_ROOT = $repo
$env:AI_REMOTE_AUTH_MODE = 'pairing'
$env:ALLOW_INSECURE_DEV_AUTH = 'false'
$env:HOST = '127.0.0.1'
$env:PORT = '8787'
$codexCommand = Get-Command codex -CommandType Application -ErrorAction Stop | Select-Object -First 1
$env:CODEX_BINARY = $codexCommand.Source
Set-Location $repo
& node --env-file=.env.local backend/src/server.mjs
