#!/bin/bash
# DieselDusel Release Script
# Usage: ./scripts/release.sh [version]
# Example: ./scripts/release.sh 2.0.0
# If no version given, patch-bumps automatically.

set -e

# ── Config ──────────────────────────────────────────────────────────────────
FLUTTER="/home/logge/flutter/bin/flutter"
REPO="LoggeL/dieseldusel-app"
# Prefer gh auth token so we never parse ~/.git-credentials.
TOKEN="${GH_TOKEN:-$(gh auth token 2>/dev/null || true)}"
[ -n "$TOKEN" ] || { echo "❌ No GitHub token. Run 'gh auth login' or set GH_TOKEN." >&2; exit 1; }

# ── Helpers ─────────────────────────────────────────────────────────────────
die() { echo "❌ $*" >&2; exit 1; }
log() { echo "▶ $*"; }

# ── Verify clean working tree ────────────────────────────────────────────────
git diff --quiet || die "Uncommitted changes. Commit or stash first."
git diff --cached --quiet || die "Staged changes. Commit first."

# ── Current version from pubspec.yaml ───────────────────────────────────────
CURRENT=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
BUILD=$(grep '^version:' pubspec.yaml | sed 's/.*+//')
log "Current: $CURRENT (build $BUILD)"

# ── Determine new version ────────────────────────────────────────────────────
if [ -n "$1" ]; then
  NEW_VERSION="$1"
else
  IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"
  PATCH=$((PATCH + 1))
  NEW_VERSION="$MAJOR.$MINOR.$PATCH"
fi
NEW_BUILD=$((BUILD + 1))
log "New version: $NEW_VERSION (build $NEW_BUILD)"

# ── Confirm ──────────────────────────────────────────────────────────────────
read -p "Release v$NEW_VERSION? [y/N] " CONFIRM
[[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]] || { echo "Aborted."; exit 0; }

# ── Create release branch ────────────────────────────────────────────────────
BRANCH="release/v$NEW_VERSION"
log "Creating branch $BRANCH..."
git checkout -b "$BRANCH"

# ── Bump versions ────────────────────────────────────────────────────────────
log "Bumping version strings..."
python3 - << PY
from pathlib import Path

# pubspec.yaml
p = Path('pubspec.yaml')
t = p.read_text()
import re
t = re.sub(r'^version: .+', f'version: $NEW_VERSION+$NEW_BUILD', t, flags=re.MULTILINE)
p.write_text(t)
print(f'  pubspec.yaml → $NEW_VERSION+$NEW_BUILD')

# key.properties — ensure correct path
kp = Path('android/key.properties')
if kp.exists():
    kt = kp.read_text()
    kt = re.sub(r'storeFile=.*', 'storeFile=keystore.jks', kt)
    kp.write_text(kt)
    print('  key.properties — storeFile=keystore.jks ✓')
PY

# ── Tests ────────────────────────────────────────────────────────────────────
log "Running tests..."
$FLUTTER test || die "Tests failed. Fix before releasing."

# ── Build APK ────────────────────────────────────────────────────────────────
log "Building release APK..."
$FLUTTER build apk --release
APK="build/app/outputs/flutter-apk/app-release.apk"
[ -f "$APK" ] || die "APK not found at $APK"
log "APK built: $(du -sh $APK | cut -f1)"

# ── Commit + push branch ─────────────────────────────────────────────────────
log "Committing version bump..."
git add pubspec.yaml
git commit -m "chore: release v$NEW_VERSION"
git push origin "$BRANCH"

# ── Create PR + merge via GitHub API ─────────────────────────────────────────
log "Creating PR..."
PR_RESP=$(curl -s -X POST "https://api.github.com/repos/$REPO/pulls" \
  -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Release v$NEW_VERSION\",\"head\":\"$BRANCH\",\"base\":\"main\",\"body\":\"Automated release v$NEW_VERSION\"}")
PR_NUMBER=$(echo "$PR_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['number'])" 2>/dev/null)
[ -n "$PR_NUMBER" ] || die "Failed to create PR: $PR_RESP"
log "PR #$PR_NUMBER created"

# ── Merge PR ─────────────────────────────────────────────────────────────────
log "Merging PR #$PR_NUMBER..."
MERGE_RESP=$(curl -s -X PUT "https://api.github.com/repos/$REPO/pulls/$PR_NUMBER/merge" \
  -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"merge_method\":\"squash\",\"commit_title\":\"chore: release v$NEW_VERSION\"}")
echo "$MERGE_RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print('Merged:', d.get('merged'))" 2>/dev/null

# Pull merged main
git checkout main
git pull origin main

# ── Tag ──────────────────────────────────────────────────────────────────────
log "Tagging v$NEW_VERSION..."
git tag "v$NEW_VERSION"
git push origin "v$NEW_VERSION"

# ── GitHub Release ───────────────────────────────────────────────────────────
log "Creating GitHub release..."
RELEASE_RESP=$(curl -s -X POST "https://api.github.com/repos/$REPO/releases" \
  -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"tag_name\":\"v$NEW_VERSION\",\"name\":\"v$NEW_VERSION\",\"body\":\"DieselDusel v$NEW_VERSION\",\"draft\":false,\"prerelease\":false}")
RELEASE_ID=$(echo "$RELEASE_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])" 2>/dev/null)
[ -n "$RELEASE_ID" ] || die "Failed to create release: $RELEASE_RESP"

# ── Upload APK ───────────────────────────────────────────────────────────────
log "Uploading APK..."
UPLOAD_RESP=$(curl -s -X POST \
  "https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets?name=app-release.apk" \
  -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/vnd.android.package-archive" \
  --data-binary "@$APK")
DOWNLOAD_URL=$(echo "$UPLOAD_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['browser_download_url'])" 2>/dev/null)

# ── Cleanup branch ───────────────────────────────────────────────────────────
git branch -D "$BRANCH" 2>/dev/null || true
git push origin --delete "$BRANCH" 2>/dev/null || true

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "✅ Released v$NEW_VERSION"
echo "   Release: https://github.com/$REPO/releases/tag/v$NEW_VERSION"
echo "   APK:     $DOWNLOAD_URL"
