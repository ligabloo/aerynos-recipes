#!/bin/sh
# Build the recipe and publish the moss repo as the assets of one GitHub release.
#
#   ./publish.sh            build recipe/stone.yaml, then upload
#   ./publish.sh --no-build upload what is already in out/
#
# The release `repo-x86_64` IS the repo: stone.index plus the .stone files beside it. moss
# resolves each PackageURI relative to the index, so the assets stay flat. dbginfo stones stay
# local. Needs boulder, moss and an authenticated gh.
set -eu

cd "$(dirname "$0")"
GH_REPO=${GH_REPO:-ligabloo/punktfunk-aerynos}
TAG=repo-x86_64
OUT=out
STAGE=$OUT/repo

if [ "${1:-}" != --no-build ]; then
    rm -f "$OUT"/*.stone
    boulder build -y -p unstable -o "$OUT" recipe/stone.yaml
fi

rm -rf "$STAGE" && mkdir -p "$STAGE"
for f in "$OUT"/*.stone; do
    case "$f" in *-dbginfo-*) continue ;; esac
    cp "$f" "$STAGE/"
done
ls "$STAGE"/*.stone >/dev/null 2>&1 || { echo "no stones in $OUT" >&2; exit 1; }
moss index -i "$STAGE"

if ! gh release view "$TAG" -R "$GH_REPO" >/dev/null 2>&1; then
    gh release create "$TAG" -R "$GH_REPO" --title "moss repo (x86_64)" --latest \
        --notes "Moss repo: \`sudo moss repo add punktfunk https://github.com/$GH_REPO/releases/download/$TAG/stone.index\`"
fi

# Old stones go first, so the index never names an asset that is missing.
keep=$(cd "$STAGE" && ls)
gh release view "$TAG" -R "$GH_REPO" --json assets -q '.assets[].name' | while read -r a; do
    echo "$keep" | grep -qx "$a" || gh release delete-asset "$TAG" "$a" -R "$GH_REPO" -y
done
gh release upload "$TAG" -R "$GH_REPO" --clobber "$STAGE"/*.stone
gh release upload "$TAG" -R "$GH_REPO" --clobber "$STAGE/stone.index"
echo "published: https://github.com/$GH_REPO/releases/download/$TAG/stone.index"
