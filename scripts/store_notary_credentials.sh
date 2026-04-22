#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_SIGNING_CONFIG="$ROOT_DIR/voiceKey/Support/Signing.local.xcconfig"
PROFILE_NAME="${VOICEKEY_NOTARY_PROFILE:-voiceKey-notary}"
APPLE_ID="${APPLE_ID:-}"
APP_SPECIFIC_PASSWORD="${APP_SPECIFIC_PASSWORD:-}"
TEAM_ID="${TEAM_ID:-}"

if [[ -z "$TEAM_ID" && -f "$LOCAL_SIGNING_CONFIG" ]]; then
  TEAM_ID="$(awk -F'=' '/VOICEKEY_DEVELOPMENT_TEAM/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$LOCAL_SIGNING_CONFIG")"
fi

if [[ -z "$APPLE_ID" || -z "$APP_SPECIFIC_PASSWORD" || -z "$TEAM_ID" ]]; then
  echo "Usage:"
  echo "  APPLE_ID='your@apple.id' APP_SPECIFIC_PASSWORD='xxxx-xxxx-xxxx-xxxx' TEAM_ID='TEAMID' \\"
  echo "    bash scripts/store_notary_credentials.sh"
  echo
  echo "Optional:"
  echo "  VOICEKEY_NOTARY_PROFILE=voiceKey-notary"
  exit 1
fi

xcrun notarytool store-credentials "$PROFILE_NAME" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_SPECIFIC_PASSWORD"

echo "Stored notary credentials in keychain profile: $PROFILE_NAME"
