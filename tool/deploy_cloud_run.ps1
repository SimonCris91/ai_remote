param(
  [string]$ProjectId = 'ai-remote-510509',
  [string]$Region = 'europe-west1',
  [string]$Service = 'ai-remote-backend',
  [string]$OpenAiSecretName = $env:AI_REMOTE_OPENAI_SECRET_NAME,
  [string]$OidcAudience = $env:AI_REMOTE_OIDC_AUDIENCE,
  [string]$AllowedEmail = $env:AI_REMOTE_GOOGLE_ALLOWED_EMAIL,
  [switch]$CreateDomainMapping
)

$ErrorActionPreference = 'Stop'
$domain = 'remote.aquariusageai.com'

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
  throw 'gcloud non è installato o non è nel PATH. Installa Google Cloud CLI e ripeti il comando.'
}
if ([string]::IsNullOrWhiteSpace($OpenAiSecretName)) {
  throw 'Imposta AI_REMOTE_OPENAI_SECRET_NAME con il nome della Secret Manager secret. Non inserire il valore della chiave.'
}
if ([string]::IsNullOrWhiteSpace($OidcAudience)) {
  throw 'Imposta AI_REMOTE_OIDC_AUDIENCE con il client ID OAuth Web pubblico.'
}
if ([string]::IsNullOrWhiteSpace($AllowedEmail)) {
  throw 'Imposta AI_REMOTE_GOOGLE_ALLOWED_EMAIL con l account proprietario autorizzato.'
}

gcloud config set project $ProjectId | Out-Null
gcloud run deploy $Service `
  --source backend `
  --project $ProjectId `
  --region $Region `
  --allow-unauthenticated `
  --set-env-vars "OIDC_ISSUER=https://accounts.google.com,OIDC_AUDIENCE=$OidcAudience,OIDC_JWKS_URL=https://www.googleapis.com/oauth2/v3/certs,GOOGLE_ALLOWED_EMAIL=$AllowedEmail,HOST=0.0.0.0" `
  --set-secrets "OPENAI_API_KEY=$($OpenAiSecretName):latest"

if ($CreateDomainMapping) {
  gcloud run domain-mappings create `
    --service $Service `
    --domain $domain `
    --project $ProjectId `
    --region $Region
}

Write-Output "Deploy completato o avviato per $Service nel progetto $ProjectId."
Write-Output "Controlla il target DNS restituito da: gcloud run domain-mappings describe --domain $domain --project $ProjectId --region $Region"
