# punktfunk for AerynOS (unofficial)

A personal moss repo for [punktfunk](https://git.unom.io/unom/punktfunk), built from the
upstream release tag with boulder. Not affiliated with or supported by the punktfunk project.

## Install

```sh
curl -fsSLO https://raw.githubusercontent.com/ligabloo/punktfunk-aerynos/main/install.sh
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

The repo itself is the `repo-x86_64` release:

```sh
sudo moss repo add punktfunk https://github.com/ligabloo/punktfunk-aerynos/releases/download/repo-x86_64/stone.index
```

## Packages

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

## Build a new version

1. In `recipe/stone.yaml`, set `version`, reset `release` to 1, and point the git upstream at
   the tag's commit: `git ls-remote https://git.unom.io/unom/punktfunk.git 'refs/tags/vX.Y.Z^{}'`.
2. If upstream moved the bun pin (`ci/bun.env`) or the Skia pin (`ci/skia-binaries.sh`),
   update those upstreams too.
3. `./publish.sh` builds against the `unstable` stream and replaces the release assets.

The boulder profile, once per machine:

```sh
boulder profile add unstable --repo 'name=unstable,base-uri=https://cdn.aerynos.dev/,channel=main,version=stream/unstable,arch=x86_64'
```

Rebuild with a higher `release` when AerynOS bumps a library soname under the packages.
