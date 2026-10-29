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

# LE LECTEUR DE CAPSULE 3D, publié sous /lecteur/. Une seule source, dans le
# moteur du Studio : on le COPIE à la construction plutôt que de le dupliquer
# dans l'application (l'appli Android l'ouvre par son adresse, cf.
# capsule_lecteur_screen.dart). Le banc d'essai et l'exemple ne partent pas.
LECTEUR=../academia_bobodo_backend/studio_visuel/lecteur
mkdir -p build/web/lecteur/assets
cp "$LECTEUR/index.html" "$LECTEUR/lecteur.js" build/web/lecteur/
cp -r "$LECTEUR/vendor" build/web/lecteur/
cp "$LECTEUR/assets/corps.json" build/web/lecteur/assets/
cp ../academia_bobodo_backend/studio_visuel/contours/index_objets.json build/web/lecteur/assets/
# Les objets du sujet ALLÉGÉS (≈ 100 Ko chacun au lieu de 4,9 Mo en médiane),
# servis par le même site que le lecteur : outils_objets/publier_objets_legers.mjs.
cp -r "$LECTEUR/assets/objets" build/web/lecteur/assets/
# Le logo de la marque, qui saute aux quatre coins (lecteur.js, comme watermark_service.dart).
cp -r "$LECTEUR/assets/marque" build/web/lecteur/assets/
