#!/bin/bash
# Re-signs a `make local` build with the Apple Development certificate.
# xcodebuild signs local builds "to run locally" even when given the identity,
# and macOS then drops Accessibility/Microphone permissions on every rebuild.
set -euo pipefail

APP="${1:?usage: sign-local-build.sh /path/to/VoiceInk.app}"
IDENTITY="${LOCAL_CODESIGN_IDENTITY:-}"

if [ -z "$IDENTITY" ]; then
  IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null | awk '/"Apple Development: / { print $2 }')
  if [ "$(printf '%s\n' "$IDENTITIES" | awk 'NF' | wc -l | tr -d ' ')" = "1" ]; then
    IDENTITY="$IDENTITIES"
  fi
fi

if [ -z "$IDENTITY" ] || [ "$IDENTITY" = "-" ]; then
  echo "No single Apple Development identity found; leaving ad-hoc signature (permissions will reset on rebuild)"
  exit 0
fi

sign() {
  codesign --force --sign "$IDENTITY" --options runtime --timestamp=none \
    --preserve-metadata=identifier,entitlements,flags "$1"
}

# nested code first, the app itself last
find "$APP/Contents" -depth \( -name "*.dylib" -o -name "Autoupdate" -o -name "*.xpc" -o -name "*.app" -o -name "*.framework" \) | while read -r item; do
  sign "$item"
done
sign "$APP"

codesign --verify --deep --strict "$APP"
echo "Signed with stable identity: $(codesign -dvv "$APP" 2>&1 | awk -F= '/^Authority=Apple Development/ { print $2; exit }')"
