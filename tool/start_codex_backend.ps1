$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$env:CODEX_HOME = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
  Join-Path $env:USERPROFILE '.codex'
} else {
  $env:CODEX_HOME
}

$env:CODEX_APP_SERVER_ENABLED = 'true'
$env:CODEX_WORKSPACE_ROOT = 'D:\Codex'
$env:CODEX_BINARY = 'codex'
Set-Location $repo
& node --env-file=.env.local backend/src/server.mjs
