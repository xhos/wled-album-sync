#!/usr/bin/env bash
set -e

: "${SPOTIFY_CLIENT_ID:?}" "${SPOTIFY_CLIENT_SECRET:?}" "${SPOTIFY_REDIRECT_URI:?}"

STATE=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32)
SCOPES="user-read-currently-playing user-read-playback-state"
ENCODED_REDIRECT=$(printf %s "$SPOTIFY_REDIRECT_URI" | jq -sRr @uri)

AUTH_URL="https://accounts.spotify.com/authorize?client_id=${SPOTIFY_CLIENT_ID}&response_type=code&redirect_uri=${ENCODED_REDIRECT}&scope=${SCOPES// /%20}&state=${STATE}"

echo "$AUTH_URL"
command -v xdg-open >/dev/null && xdg-open "$AUTH_URL" 2>/dev/null || true

read -r -p "Paste redirect URL: " REDIRECT_RESPONSE

CODE=$(echo "$REDIRECT_RESPONSE" | sed -n 's/.*code=\([^&]*\).*/\1/p')
[ -z "$CODE" ] && echo "no code found" && exit 1

RESPONSE=$(curl -s -X POST "https://accounts.spotify.com/api/token" \
    -d "grant_type=authorization_code" \
    -d "code=${CODE}" \
    -d "redirect_uri=${SPOTIFY_REDIRECT_URI}" \
    -d "client_id=${SPOTIFY_CLIENT_ID}" \
    -d "client_secret=${SPOTIFY_CLIENT_SECRET}")

REFRESH=$(echo "$RESPONSE" | jq -r '.refresh_token // empty')
[ -z "$REFRESH" ] && echo "$RESPONSE" && exit 1

echo
echo "SPOTIFY_REFRESH_TOKEN=$REFRESH"
