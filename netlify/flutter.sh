#!/usr/bin/env bash
set -e

echo "Installing Flutter..."
if [ ! -d flutter ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
else
  echo "Flutter directory already exists, reusing cached SDK."
fi
export PATH="$PATH:`pwd`/flutter/bin"

flutter doctor

cd academia_app

flutter build web --web-renderer html
