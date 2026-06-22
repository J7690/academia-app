# Bobodo Voice V1 - Script de déploiement complet
# Ce script déploie l'Edge Function bobodo-chat avec le support streaming

# Variables
$SUPABASE_URL = $env:SUPABASE_URL
$SUPABASE_ACCESS_TOKEN = $env:SUPABASE_ACCESS_TOKEN

Write-Host "=== Bobodo Voice V1 - Déploiement complet ===" -ForegroundColor Cyan
Write-Host ""

# Vérifier les variables d'environnement
if (-not $SUPABASE_URL -or -not $SUPABASE_ACCESS_TOKEN) {
    Write-Host "ERREUR: Variables d'environnement SUPABASE_URL et SUPABASE_ACCESS_TOKEN requises" -ForegroundColor Red
    exit 1
}

Write-Host "1. Déploiement de l'Edge Function bobodo-chat avec support streaming..." -ForegroundColor Yellow
supabase functions deploy bobodo-chat --no-verify-jwt

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERREUR: Échec du déploiement de bobodo-chat" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Edge Function bobodo-chat déployée avec succès" -ForegroundColor Green
Write-Host ""

Write-Host "2. Vérification du déploiement..." -ForegroundColor Yellow
$healthCheck = Invoke-WebRequest -Uri "$SUPABASE_URL/functions/v1/bobodo-chat" -Method GET -Headers @{
    "Authorization" = "Bearer $SUPABASE_ACCESS_TOKEN"
    "apikey" = $SUPABASE_ACCESS_TOKEN
} -UseBasicParsing

if ($healthCheck.StatusCode -eq 200 -or $healthCheck.StatusCode -eq 405) {
    Write-Host "✓ Edge Function bobodo-chat accessible" -ForegroundColor Green
} else {
    Write-Host "ERREUR: Edge Function bobodo-chat non accessible" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Déploiement terminé avec succès ===" -ForegroundColor Green
Write-Host ""
Write-Host "Prochaines étapes:" -ForegroundColor Cyan
Write-Host "1. Tester l'Edge Function avec le paramètre ?stream=true" -ForegroundColor White
Write-Host "2. Déployer l'application Flutter sur appareil réel" -ForegroundColor White
Write-Host "3. Tester le mode conversation complet" -ForegroundColor White
