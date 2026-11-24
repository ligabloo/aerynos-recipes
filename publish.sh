#!/bin/sh
# Build recipes and publish them into the moss repo: the assets of one GitHub release.
#
#   ./publish.sh NAME...             build recipes/NAME, then publish it
#   ./publish.sh --no-build NAME...  publish what is already in out/NAME
#
# The release `repo-x86_64` IS the repo: stone.index plus the .stone files beside it, flat,
# because moss resolves each PackageURI relative to the index. Packages from recipes not named
# here stay as they are. dbginfo stones stay local. Needs boulder, moss and an authenticated gh.
set -eu

cd "$(dirname "$0")"
GH_REPO=${GH_REPO:-ligabloo/aerynos-recipes}
TAG=repo-x86_64
STAGE=out/.repo

BUILD=1
[ "${1:-}" = --no-build ] && { BUILD=0; shift; }
[ $# -gt 0 ] || { sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
for r in "$@"; do
    [ -f "recipes/$r/stone.yaml" ] || { echo "no recipe: recipes/$r/stone.yaml" >&2; exit 1; }
done

# A stone is NAME-VERSION-RELEASE-BUILD-ARCH.stone.
pkg_name() { basename "$1" | sed 's/-[^-]*-[^-]*-[^-]*-[^-]*\.stone$//'; }

if [ "$BUILD" = 1 ]; then
    for r in "$@"; do
        mkdir -p "out/$r"
        rm -f "out/$r"/*.stone
        boulder build -y -p unstable -o "out/$r" "recipes/$r/stone.yaml"
    done
fi

if ! gh release view "$TAG" -R "$GH_REPO" >/dev/null 2>&1; then
    gh release create "$TAG" -R "$GH_REPO" --title "moss repo (x86_64)" --latest \
        --notes "Moss repo: \`sudo moss repo add aerynos-recipes https://github.com/$GH_REPO/releases/download/$TAG/stone.index\`"
fi

# Start from what is published, then swap in every package the named recipes built.
rm -rf "$STAGE" && mkdir -p "$STAGE"
gh release download "$TAG" -R "$GH_REPO" -p '*.stone' -D "$STAGE" 2>/dev/null || true
NEW=""
for r in "$@"; do
    found=0
    for f in "out/$r"/*.stone; do
        [ -e "$f" ] || continue
        case "$f" in *-dbginfo-*) continue ;; esac
        found=1
        n=$(pkg_name "$f")
        for old in "$STAGE"/*.stone; do
            if [ -e "$old" ] && [ "$(pkg_name "$old")" = "$n" ]; then rm -f "$old"; fi
        done
        cp "$f" "$STAGE/"
        NEW="$NEW $STAGE/$(basename "$f")"
    done
    [ "$found" = 1 ] || { echo "no stones in out/$r" >&2; exit 1; }
done
moss index -i "$STAGE"

# New stones, then the index, then stale stones: the live index never names a missing asset.
# shellcheck disable=SC2086
gh release upload "$TAG" -R "$GH_REPO" --clobber $NEW
gh release upload "$TAG" -R "$GH_REPO" --clobber "$STAGE/stone.index"
keep=$(cd "$STAGE" && ls)
gh release view "$TAG" -R "$GH_REPO" --json assets -q '.assets[].name' | while read -r a; do
    echo "$keep" | grep -qx "$a" || gh release delete-asset "$TAG" "$a" -R "$GH_REPO" -y
done
echo "published: https://github.com/$GH_REPO/releases/download/$TAG/stone.index"
