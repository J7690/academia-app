#!/usr/bin/env bash
set -e

echo "Installing Flutter..."
rm -rf flutter
git clone https://github.com/flutter/flutter.git --branch 3.38.6 --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

flutter doctor

cd academia_app

flutter pub get --enforce-lockfile
# --pwa-strategy=none : pas de service worker Flutter -> plus de cache-first
# qui servait d'anciennes versions cassees (ecran gris). Avec les headers
# no-cache de Netlify, l'app charge toujours la derniere version.
flutter build web --release --pwa-strategy=none
