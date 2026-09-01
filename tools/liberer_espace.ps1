<#
.SYNOPSIS
    Libère de l'espace disque en supprimant uniquement ce qui se régénère.

.DESCRIPTION
    Trois paliers, du plus sûr au plus coûteux à reconstruire. Rien de ce qui
    est supprimé ici n'est du code source : tout revient au prochain
    `flutter pub get` / `flutter build` / `npm ci`.

    PALIER 1 — sorties de compilation (défaut)
        Reconstruit en quelques minutes. Aucun téléchargement réseau.

    PALIER 2 — caches de dépendances  (-Profond)
        Gradle et Pub. Reconstruit automatiquement, MAIS re-télécharge
        plusieurs centaines de Mo. À éviter si la connexion est limitée.

    PALIER 3 — journaux de diagnostic  (-Journaux)
        Vidages logcat et sorties d'analyse accumulés dans le dépôt.

.EXAMPLE
    # Voir ce qui serait supprimé, sans rien toucher :
    .\tools\liberer_espace.ps1 -Simulation

.EXAMPLE
    # Nettoyage standard (sorties de compilation) :
    .\tools\liberer_espace.ps1

.EXAMPLE
    # Nettoyage maximal :
    .\tools\liberer_espace.ps1 -Profond -Journaux

.NOTES
    Créé le 31/07/2026. Ne supprime JAMAIS : code source, .env, clés SSH,
    pubspec.yaml, documents. Uniquement des artefacts régénérables.
#>

[CmdletBinding()]
param(
    [switch]$Simulation,   # n'efface rien, se contente de mesurer
    [switch]$Profond,      # ajoute les caches Gradle et Pub (re-téléchargement)
    [switch]$Journaux      # ajoute les vidages de logs du dépôt
)

$ErrorActionPreference = 'Continue'
$racine = Split-Path -Parent $PSScriptRoot

function Get-TailleMo {
    param([string]$Chemin)
    if (-not (Test-Path -LiteralPath $Chemin)) { return $null }
    try {
        $octets = (Get-ChildItem -LiteralPath $Chemin -Recurse -Force -File -ErrorAction SilentlyContinue |
                   Measure-Object -Property Length -Sum).Sum
        if (-not $octets) { return 0 }
        return [math]::Round($octets / 1MB, 1)
    } catch { return $null }
}

$cibles = @()

# ── PALIER 1 : sorties de compilation ────────────────────────────────────
# Régénérées par `flutter build`. Aucun téléchargement nécessaire.
$cibles += @(
    @{ Chemin = Join-Path $racine 'build';                              Palier = 1; Note = 'Sortie de build (projet racine)' }
    @{ Chemin = Join-Path $racine '.dart_tool';                         Palier = 1; Note = 'Cache Dart (projet racine)' }
    @{ Chemin = Join-Path $racine 'academia_app\build';                 Palier = 1; Note = 'Sortie de build (application)' }
    @{ Chemin = Join-Path $racine 'academia_app\.dart_tool';            Palier = 1; Note = 'Cache Dart (application)' }
    @{ Chemin = Join-Path $racine 'academia_app\android\.gradle';       Palier = 1; Note = 'État Gradle du projet' }
    @{ Chemin = Join-Path $racine 'android\.gradle';                    Palier = 1; Note = 'État Gradle (racine)' }
    @{ Chemin = Join-Path $racine 'academia_app\android\app\build';     Palier = 1; Note = 'Build Android (app)' }
    @{ Chemin = Join-Path $racine 'academia_app\.flutter-plugins-dependencies'; Palier = 1; Note = 'Index des plugins' }
    # Moteur de rendu : réinstallé par `npm ci`, mais lourd (Chromium compris).
    @{ Chemin = Join-Path $racine 'whiteboard_engine_remotion\node_modules'; Palier = 1; Note = 'Dépendances Node (npm ci)' }
)

# ── PALIER 2 : caches de dépendances (re-téléchargement réseau) ───────────
if ($Profond) {
    $cibles += @(
        @{ Chemin = Join-Path $env:USERPROFILE '.gradle\caches';   Palier = 2; Note = 'Cache Gradle global — souvent le plus gros' }
        @{ Chemin = Join-Path $env:USERPROFILE '.gradle\daemon';   Palier = 2; Note = 'Journaux du démon Gradle' }
        @{ Chemin = Join-Path $env:LOCALAPPDATA 'Pub\Cache';       Palier = 2; Note = 'Paquets Dart/Flutter (flutter pub get)' }
        @{ Chemin = Join-Path $env:USERPROFILE '.pub-cache';       Palier = 2; Note = 'Paquets Dart (emplacement alternatif)' }
    )
}

# ── PALIER 3 : journaux de diagnostic accumulés dans le dépôt ────────────
if ($Journaux) {
    $cibles += @(
        @{ Chemin = Join-Path $racine 'academia_app\full_video_audit.txt';  Palier = 3; Note = 'Vidage logcat (audit vidéo)' }
        @{ Chemin = Join-Path $racine 'academia_app\flutter_analyze_full.txt'; Palier = 3; Note = 'Sortie flutter analyze' }
    )
    # Journaux bruts de sessions Windsurf
    Get-ChildItem -LiteralPath (Join-Path $racine '.windsurf') -Filter '*.log' -File -ErrorAction SilentlyContinue |
        ForEach-Object { $cibles += @{ Chemin = $_.FullName; Palier = 3; Note = 'Journal de session Windsurf' } }
}

# ── Exécution ────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '  LIBÉRATION D''ESPACE — Academia' -ForegroundColor Cyan
if ($Simulation) { Write-Host '  MODE SIMULATION : rien ne sera supprimé' -ForegroundColor Yellow }
Write-Host ('  ' + ('─' * 62))

$total = 0.0
foreach ($cible in $cibles) {
    $taille = Get-TailleMo -Chemin $cible.Chemin
    if ($null -eq $taille) { continue }   # n'existe pas : on passe

    $total += $taille
    $affichage = '{0,9:N1} Mo  P{1}  {2}' -f $taille, $cible.Palier, $cible.Note
    Write-Host "  $affichage" -ForegroundColor Gray

    if (-not $Simulation) {
        try {
            Remove-Item -LiteralPath $cible.Chemin -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "      ⚠ non supprimé : $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    }
}

Write-Host ('  ' + ('─' * 62))
$verbe = if ($Simulation) { 'récupérables' } else { 'libérés' }
Write-Host ('  {0:N1} Mo {1}  ({2:N2} Go)' -f $total, $verbe, ($total / 1024)) -ForegroundColor Green
Write-Host ''

if (-not $Simulation) {
    Write-Host '  Pour reconstruire ensuite :' -ForegroundColor Cyan
    Write-Host '    cd academia_app && flutter pub get && flutter analyze' -ForegroundColor Gray
    if ($Profond) {
        Write-Host '    (le premier build re-téléchargera les dépendances Gradle)' -ForegroundColor DarkGray
    }
    Write-Host ''
}
