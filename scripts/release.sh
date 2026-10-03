#!/bin/zsh
# Bumps catalogVersion to today's date (+ counter), validates and signs catalog.json with the
# offline key, commits, tags and publishes a GitHub release with catalog.json + catalog.json.sig.
#   scripts/release.sh [signing key]   (default ~/.config/macmcp-signing/catalog-signing.key)
# The signing key is created once with `macmcpctl catalog keygen ~/.config/macmcp-signing`.
set -euo pipefail
cd "${0:A:h}/.."
KEY="${1:-$HOME/.config/macmcp-signing/catalog-signing.key}"
CTL="${MACMCPCTL:-$(command -v macmcpctl || echo "$HOME/Library/Caches/MacMCP-build/spm/debug/macmcpctl")}"
[[ -f "$KEY" ]] || { echo "signing key not found: $KEY" >&2; exit 1; }
[[ -x "$CTL" ]] || { echo "macmcpctl not found (run make ctl in ../macMCP)" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "working tree not clean" >&2; exit 1; }
git pull --ff-only

today=$(date +%Y.%m.%d)
n=1
while git rev-parse -q --verify "refs/tags/$today.$n" >/dev/null; do n=$((n + 1)); done
version="$today.$n"
sed -i '' -E "1,5s/\"catalogVersion\": \"[^\"]*\"/\"catalogVersion\": \"$version\"/" catalog.json
grep -q "\"catalogVersion\": \"$version\"" catalog.json || { echo "could not set catalogVersion" >&2; exit 1; }

swift scripts/validate.swift catalog.json
"$CTL" catalog validate catalog.json
"$CTL" catalog sign catalog.json --key "$KEY"
"$CTL" catalog verify catalog.json --public-key "$(cat "${KEY:r}.pub")"
git add catalog.json catalog.json.sig
git commit -m "Release catalog $version"
git tag "$version"
git push origin HEAD --tags
gh release create "$version" catalog.json catalog.json.sig --title "Catalog $version" --notes "Signed macMCP catalog $version."
echo "Published $version"
