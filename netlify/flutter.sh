#!/usr/bin/env bash
set -e

echo "Installing Flutter..."
rm -rf flutter
git clone https://github.com/flutter/flutter.git --branch 3.38.6 --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

flutter doctor

cd academia_app

flutter pub get --enforce-lockfile
flutter build web --release
