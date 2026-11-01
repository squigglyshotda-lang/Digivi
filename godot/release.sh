#!/bin/bash
# Publishes build/digivi.apk: copies it to downloads/, writes version.json, commits and pushes.
set -e
cd "$(dirname "$0")"
CODE=$(grep -m1 '^version/code=' export_presets.cfg | cut -d= -f2)
NAME=$(grep -m1 '^version/name=' export_presets.cfg | cut -d'"' -f2)
NOTES="${1:-Improvements}"
cp build/digivi.apk ../downloads/digivi-latest.apk
printf '{"code": %s, "name": "%s", "apk": "digivi-latest.apk", "notes": "%s"}\n' "$CODE" "$NAME" "$NOTES" > ../downloads/version.json
sed -i -E "s/\([0-9]+\.[0-9]+\.[0-9]+, /($NAME, /" ../downloads/index.html
cd ..
git add -A
git commit -qm "Release $NAME: $NOTES

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HAWdsC16VegWb2PC1kRLmB"
git push -q
