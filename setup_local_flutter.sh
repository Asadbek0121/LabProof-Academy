#!/usr/bin/env bash
# Exit on error
set -e

LOCAL_FLUTTER="/Users/macbookairm1/Documents/New project 3/local_flutter"
GLOBAL_FLUTTER="/opt/homebrew/share/flutter"

echo "Creating local Flutter directories..."
mkdir -p "$LOCAL_FLUTTER"
mkdir -p "$LOCAL_FLUTTER/bin"
mkdir -p "$LOCAL_FLUTTER/bin/cache"

echo "Copying scripts and metadata..."
cp "$GLOBAL_FLUTTER/bin/flutter" "$LOCAL_FLUTTER/bin/flutter"
cp "$GLOBAL_FLUTTER/bin/dart" "$LOCAL_FLUTTER/bin/dart"
cp -R "$GLOBAL_FLUTTER/bin/internal" "$LOCAL_FLUTTER/bin/internal"

echo "Symlinking root level directories..."
ln -sf "$GLOBAL_FLUTTER/packages" "$LOCAL_FLUTTER/packages"
ln -sf "$GLOBAL_FLUTTER/dev" "$LOCAL_FLUTTER/dev"
ln -sf "$GLOBAL_FLUTTER/examples" "$LOCAL_FLUTTER/examples"
ln -sf "$GLOBAL_FLUTTER/analysis_options.yaml" "$LOCAL_FLUTTER/analysis_options.yaml"

echo "Symlinking large cache directories..."
ln -sf "$GLOBAL_FLUTTER/bin/cache/artifacts" "$LOCAL_FLUTTER/bin/cache/artifacts"
ln -sf "$GLOBAL_FLUTTER/bin/cache/dart-sdk" "$LOCAL_FLUTTER/bin/cache/dart-sdk"
ln -sf "$GLOBAL_FLUTTER/bin/cache/flutter_web_sdk" "$LOCAL_FLUTTER/bin/cache/flutter_web_sdk"
ln -sf "$GLOBAL_FLUTTER/bin/cache/pkg" "$LOCAL_FLUTTER/bin/cache/pkg"

echo "Copying files/stamps from global cache..."
for f in "$GLOBAL_FLUTTER"/bin/cache/*; do
  if [ -f "$f" ]; then
    cp "$f" "$LOCAL_FLUTTER/bin/cache/"
  fi
done

# Ensure they are writable
chmod -R u+w "$LOCAL_FLUTTER"

echo "Local Flutter SDK successfully configured at: $LOCAL_FLUTTER"
