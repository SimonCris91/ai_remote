$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$authPath = Join-Path $env:USERPROFILE '.codex\auth.json'
if (-not (Test-Path -LiteralPath $authPath)) { throw 'Codex auth.json non trovato.' }
$auth = Get-Content -Raw -LiteralPath $authPath | ConvertFrom-Json
$accessToken = $auth.tokens.access_token
if ([string]::IsNullOrWhiteSpace($accessToken)) { throw 'Access token Codex non disponibile.' }

$env:CODEX_APP_SERVER_ENABLED = 'true'
$env:CODEX_ACCESS_TOKEN = $accessToken
$env:CODEX_WORKSPACE_ROOT = 'D:\Codex'
$env:CODEX_MODEL = 'gpt-5-codex'
$env:CODEX_BINARY = 'codex'
Set-Location $repo
& node --env-file=.env.local backend/src/server.mjs
