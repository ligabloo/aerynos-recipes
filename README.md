# aerynos-recipes

Personal [AerynOS](https://aerynos.com) packages, built with boulder and served as a moss repo
from this repo's `repo-x86_64` release. Unofficial, and not affiliated with the upstream projects.

```sh
sudo moss repo add aerynos-recipes https://github.com/ligabloo/aerynos-recipes/releases/download/repo-x86_64/stone.index
sudo moss repo update aerynos-recipes
```

## Recipes

| recipe | what |
| --- | --- |
| [`punktfunk`](recipes/punktfunk) | [punktfunk](https://git.unom.io/unom/punktfunk) game streaming host and client |
| [`rex-gtk`](recipes/rex-gtk) | GTK client for the [Rex](https://superlogical.com) terminal multiplexer |

## Layout

```
recipes/NAME/stone.yaml   the boulder recipe
recipes/NAME/...          anything else the package needs, such as an install helper
out/NAME/                 build output (not committed)
```

## Build and publish

Once per machine, a boulder profile matching the system's stream:

```sh
boulder profile add unstable --repo 'name=unstable,base-uri=https://cdn.aerynos.dev/,channel=main,version=stream/unstable,arch=x86_64'
```

Then:

```sh
./publish.sh punktfunk              # build, then publish
./publish.sh --no-build punktfunk   # publish what is already in out/punktfunk
```

`publish.sh` swaps in only the packages the named recipes built and keeps everything else in the
release. Rebuild with a higher `release` when AerynOS bumps a library soname under a package.

## rex-gtk

```sh
sudo moss repo update aerynos-recipes
sudo moss pkg add rex-gtk
```

To build a new version: in `recipes/rex-gtk/stone.yaml`, set `version`, reset `release` to 1,
and point the git upstream at the new commit of https://github.com/ligabloo/rex-gtk.

## punktfunk

```sh
curl -fsSLO https://raw.githubusercontent.com/ligabloo/aerynos-recipes/main/recipes/punktfunk/install.sh
sh install.sh            # host, console, script runner and client
sh install.sh --host     # streaming box only
sh install.sh --client   # client only
sh install.sh update     # use this instead of a bare `moss sync`
sh install.sh uninstall
```

moss runs no package scriptlets, so `install.sh` does what the Arch `.install` files do
upstream: the encode worker's `cap_sys_nice`, the sysctl drop-ins, `post-install`, the
`input` group, and enabling `punktfunk-scripting` for every user. A bare `moss sync` drops the
worker's capability until the next `install.sh update`.

| package | what |
| --- | --- |
| `punktfunk` | metapackage: host, client, web, scripting |
| `punktfunk-host` | host, encode worker, tray, udev/polkit/sysctl drop-ins |
| `punktfunk-client` | GTK4 client, session streamer, `punktfunk` CLI |
| `punktfunk-web` | browser console |
| `punktfunk-scripting` | plugin and script runner |
| `punktfunk-seats` | seat supervisor and door (ships disabled) |
| `punktfunk-bun`, `punktfunk-icons` | shared runtime and icons |

Differences from the Arch packages: no `/etc` files (no ufw profile, no gamescope-session
drop-in, no AppArmor profile), no Omarchy integration, no HDR `punktfunk-gamescope`, and no
`pf-update` (the console can't apply updates; `install.sh update` does). The PAM file lives in
`/usr/share/defaults/pam.d`.

The console's login password is in `~/.config/punktfunk/web-password`. To change it, make that
file the single line `PUNKTFUNK_UI_PASSWORD=<new>` and run `systemctl --user restart punktfunk-web`.

To build a new version: in `recipes/punktfunk/stone.yaml`, set `version`, reset `release` to 1,
and point the git upstream at the tag's commit
(`git ls-remote https://git.unom.io/unom/punktfunk.git 'refs/tags/vX.Y.Z^{}'`). If upstream moved
the bun pin (`ci/bun.env`) or the Skia pin (`ci/skia-binaries.sh`), update those upstreams too.
Then `./publish.sh punktfunk`.
