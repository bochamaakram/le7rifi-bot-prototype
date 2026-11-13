#!/bin/sh
# Build a checked, installable development APK. Run on a network-enabled host.
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
flutter_bin=${FLUTTER_BIN:-flutter}
api_url=${API_URL:-http://10.0.2.2:8000}

if ! command -v "$flutter_bin" >/dev/null 2>&1; then
    echo 'Flutter was not found. Add Flutter to PATH or set FLUTTER_BIN.' >&2
    exit 1
fi

cd "$project_root/mobile"
"$flutter_bin" pub get
"$flutter_bin" analyze --no-pub
"$flutter_bin" test --no-pub
"$flutter_bin" build apk --debug --no-pub --dart-define="API_URL=$api_url"

apk=build/app/outputs/flutter-apk/app-debug.apk
if [ ! -s "$apk" ]; then
    echo 'The build did not produce an APK.' >&2
    exit 1
fi
mkdir -p "$project_root/artifacts"
cp "$apk" "$project_root/artifacts/le7rayfi-ai-debug.apk"
printf '\nAPK: %s/artifacts/le7rayfi-ai-debug.apk\n' "$project_root"
printf 'Backend: %s\n' "$api_url"
echo 'Install with: adb install -r artifacts/le7rayfi-ai-debug.apk'
