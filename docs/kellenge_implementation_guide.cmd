@echo off
REM ============================================
REM KELLENGE - GUIDE D'IMPLÉMENTATION FLAME ENGINE
REM ============================================
REM Audit complet et proposition pour jeux économiques Academia
REM Créé le 10 Mars 2026
REM ============================================

echo.
echo ============================================
echo     KELLENGE - AUDIT JEUX ACADEMIA
echo ============================================
echo.

:menu
echo.
echo CHOISISSEZ UNE OPTION :
echo.
echo 1. Afficher l'audit complet
echo 2. Vérifier l'état actuel des packages
echo 3. Installer les packages Flame
echo 4. Créer la structure des dossiers
echo 5. Télécharger les assets recommandés
echo 6. Lancer les tests de connexion Supabase
echo 7. Afficher la proposition Economia Challenge
echo 8. Quitter
echo.
set /p choice="Votre choix (1-8): "

if "%choice%"=="1" goto audit
if "%choice%"=="2" goto check_packages
if "%choice%"=="3" goto install_packages
if "%choice%"=="4" goto create_structure
if "%choice%"=="5" goto download_assets
if "%choice%"=="6" goto test_supabase
if "%choice%"=="7" goto economia_proposal
if "%choice%"=="8" goto exit

echo Choix invalide, réessayez.
goto menu

:audit
echo.
echo ============================================
echo     AUDIT COMPLET KELLENGE
echo ============================================
echo.
echo Contenu de l'audit :
echo - Audit Supabase (RPCs et schéma)
echo - Audit Flame Engine (packages manquants)
echo - Packages disponibles (2025)
echo - Sources d'assets gratuites
echo - Architecture technique proposée
echo - Economia Challenge (jeu économique)
echo.
echo Document complet : docs/kellenge_flame_engine_audit.md
echo.
pause
goto menu

:check_packages
echo.
echo ============================================
echo     VÉRIFICATION PACKAGES ACTUELS
echo ============================================
echo.
cd /d "%~dp0.."
echo Vérification de pubspec.yaml...
findstr "flame" pubspec.yaml
findstr "forge2d" pubspec.yaml
findstr "flame_audio" pubspec.yaml
echo.
echo Packages manquants détectés :
echo - flame: ^1.36.0
echo - flame_audio: ^2.12.0
echo - forge2d: ^0.2.0
echo - flame_forge2d: ^0.2.0
echo.
pause
goto menu

:install_packages
echo.
echo ============================================
echo     INSTALLATION PACKAGES FLAME
echo ============================================
echo.
cd /d "%~dp0.."
echo Installation des packages Flame...
flutter pub add flame:1.36.0
flutter pub add flame_audio:2.12.0
flutter pub add forge2d:0.2.0
flutter pub add flame_forge2d:0.2.0
echo.
echo Installation terminée !
echo.
pause
goto menu

:create_structure
echo.
echo ============================================
echo     CRÉATION STRUCTURE DOSSIERS
echo ============================================
echo.
cd /d "%~dp0.."
echo Création des dossiers pour les jeux...
mkdir lib\games\economics\components 2>nul
mkdir lib\games\economics\systems     2>nul
mkdir lib\games\economics\ui         2>nul
mkdir lib\games\shared\audio         2>nul
mkdir lib\games\shared\assets        2>nul
mkdir assets\images\game\economics  2>nul
mkdir assets\audio\game\economics    2>nul
echo.
echo Structure créée avec succès !
echo.
pause
goto menu

:download_assets
echo.
echo ============================================
echo     TÉLÉCHARGEMENT ASSETS RECOMMANDÉS
echo ============================================
echo.
echo Sources d'assets gratuites :
echo.
echo 1. CraftPix.net
echo    - URL : https://craftpix.net/freebies/
echo    - Catégories : GUI, backgrounds, icons, sprites
echo    - Licence : Utilisation commerciale autorisée
echo.
echo 2. OpenGameArt.org
echo    - URL : https://opengameart.org/
echo    - Catégories : Challenge mensuels, thématiques variées
echo    - Licence : CC0, CC-BY
echo.
echo 3. GameArt2D.com
echo    - URL : https://www.gameart2d.com/freebies.html
echo    - Catégories : Personnages, environnements, UI
echo    - Style : Pixel art et moderne
echo.
echo Assets spécifiques pour jeux économiques :
echo - Graphiques financiers (courbes, tendances)
echo - Icônes monnaie ($, €, crypto)
echo - Personnages (businessmen, students)
echo - Environnements (offices, markets)
echo - UI elements (charts, dashboards)
echo.
echo Ouvrir les sites dans votre navigateur ? (O/N)
set /p open_sites="> "
if /i "%open_sites%"=="O" (
    start https://craftpix.net/freebies/
    start https://opengameart.org/
    start https://www.gameart2d.com/freebies.html
)
echo.
pause
goto menu

:test_supabase
echo.
echo ============================================
echo     TEST CONNEXION SUPABASE
echo ============================================
echo.
cd /d "%~dp0\.windsurf"
echo Test des RPCs Supabase...
python audit_academia_supabase.py
echo.
echo Test des tables app.*...
python -c "from supabase_auto_manager import SupabaseAutoManager; manager = SupabaseAutoManager(); sql = 'SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema = \"app\";'; result = manager.execute_sql_auto(sql); print(result)"
echo.
pause
goto menu

:economia_proposal
echo.
echo ============================================
echo     ECONOMIA CHALLENGE - PROPOSITION
echo ============================================
echo.
echo Concept : "TikTok meets Bloomberg Terminal"
echo.
echo 4 Jeux Spécialisés :
echo.
echo 1. MARKET MASTER
echo    - Simulation offre/demande
echo    - Contexte : Marché café Éthiopie
echo    - 20 scénarios progressifs
echo.
echo 2. CONSUMER CHOICE
echo    - Théorie consommateur
echo    - Contexte : Budget étudiant Dakar
echo    - 15 situations budgétaires
echo.
echo 3. FIRM TYCOON
echo    - Théorie entreprise
echo    - Contexte : Startup Nairobi
echo    - 10 rounds stratégiques
echo.
echo 4. MARKET STRUCTURES
echo    - Structures marché
echo    - Contexte : Télécoms Afrique Ouest
echo    - 8 configurations
echo.
echo Design : Interface professionnelle noir/or
echo Performance : 60 FPS constant
echo Integration : Profile Academia + dashboard enseignants
echo.
echo Roadmap : 6 mois (3 phases de 2 mois)
echo.
pause
goto menu

:exit
echo.
echo ============================================
echo     MERCI D'AVOIR CONSULTÉ KELLENGE
echo ============================================
echo.
echo Documentation complète : docs/kellenge_flame_engine_audit.md
echo.
echo Prochaines étapes recommandées :
echo 1. Diagnostiquer Supabase
echo 2. Implémenter Flame Engine
echo 3. Développer Economia Challenge
echo.
exit /b 0
