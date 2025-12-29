#!/usr/bin/env bash
set -e

echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

flutter doctor

cd academia_app

flutter build web
