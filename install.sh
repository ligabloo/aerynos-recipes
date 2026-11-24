#!/bin/sh
# punktfunk on AerynOS: an unofficial moss repo, for personal use.
#
#   curl -fsSL https://raw.githubusercontent.com/ligabloo/punktfunk-aerynos/main/install.sh | sh
#   sh install.sh [install] [--host|--client|--all]   default --all
#   sh install.sh update
#   sh install.sh uninstall
#
# moss runs no package scriptlets, so this script does what the pacman .install files do:
# the encode worker's capability, the sysctl drop-ins, the post-install script, and enabling
# the plugin runner for every user. Run `update` after each moss sync for the same reason.
set -eu

REPO_NAME=punktfunk
INDEX_URL=${PUNKTFUNK_MOSS_INDEX:-https://github.com/ligabloo/punktfunk-aerynos/releases/download/repo-x86_64/stone.index}

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m  xx\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '2,11p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

CMD=install
SET=all
for arg in "$@"; do
    case "$arg" in
        install|update|uninstall) CMD=$arg ;;
        --all) SET=all ;;
        --host) SET=host ;;
        --client) SET=client ;;
        -h|--help) usage 0 ;;
        *) warn "unknown argument: $arg"; usage 2 ;;
    esac
done

# --- preflight -----------------------------------------------------------------------------
[ "$(uname -s)" = Linux ] || die "This is for AerynOS. Other systems: https://docs.punktfunk.unom.io/docs/install"
[ "$(uname -m)" = x86_64 ] || die "This repo only has x86_64 builds."
ID=""
[ -r /etc/os-release ] && . /etc/os-release
case "${ID:-}" in
    aerynos) ;;
    *) die "This is for AerynOS, and this box is ${PRETTY_NAME:-unknown}. Other systems: https://docs.punktfunk.unom.io/docs/install" ;;
esac
command -v moss >/dev/null 2>&1 || die "moss is missing, so this isn't a working AerynOS install."

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
    TARGET_USER=${SUDO_USER:-}
else
    command -v sudo >/dev/null 2>&1 || die "Run this as root, or install sudo first."
    SUDO=sudo
    TARGET_USER=$(id -un)
fi
as_root() { $SUDO "$@"; }

have_repo() { moss repo list 2>/dev/null | grep -q "^ *- $REPO_NAME = "; }
installed() { moss pkg info "$1" 2>/dev/null | grep -q '^Status *Installed'; }

# --- the scriptlet work moss skips ---------------------------------------------------------
post_steps() {
    if installed punktfunk-host; then
        say "Host: encode worker capability, network buffers, groups"
        # The host must stay capability-free or KWin can't identify it; only the worker gets one.
        as_root setcap -r /usr/bin/punktfunk-host 2>/dev/null || true
        as_root setcap cap_sys_nice=ep /usr/bin/punktfunk-encode-worker \
            || warn "Couldn't give the encode worker its scheduling priority. Streaming still works."
        as_root sysctl -q -p /usr/lib/sysctl.d/99-punktfunk-net.conf || true
        as_root /usr/lib/punktfunk/post-install || true
        as_root modprobe vhci-hcd 2>/dev/null || true
        if [ -n "$TARGET_USER" ] && ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx input; then
            as_root usermod -aG input "$TARGET_USER"
            NEED_RELOGIN=1
        fi
    fi
    if installed punktfunk-client; then
        as_root sysctl -q -p /usr/lib/sysctl.d/99-punktfunk-client-net.conf || true
        as_root udevadm control --reload-rules 2>/dev/null || true
        as_root udevadm trigger --subsystem-match=hidraw 2>/dev/null || true
    fi
    if installed punktfunk-scripting; then
        as_root systemctl --global enable punktfunk-scripting.service >/dev/null 2>&1 || true
    fi
}

restart_units() {
    [ -x /usr/lib/punktfunk/restart-user-units ] || return 0
    as_root /usr/lib/punktfunk/restart-user-units || true
}

# --- commands ------------------------------------------------------------------------------
do_install() {
    case "$SET" in
        all)    PKGS="punktfunk punktfunk-host punktfunk-client punktfunk-web punktfunk-scripting" ;;
        host)   PKGS="punktfunk-host punktfunk-web punktfunk-scripting" ;;
        client) PKGS="punktfunk-client" ;;
    esac

    if have_repo; then
        say "Repo '$REPO_NAME' is already set up"
    else
        say "Adding the '$REPO_NAME' moss repo"
        as_root moss repo add "$REPO_NAME" "$INDEX_URL" -c "Unofficial punktfunk builds"
    fi
    as_root moss repo update "$REPO_NAME"

    say "Installing: $PKGS"
    # shellcheck disable=SC2086
    as_root moss -y pkg add $PKGS
    NEED_RELOGIN=0
    post_steps

    echo
    say "Done."
    if installed punktfunk-host; then
        cat <<'EOF'
  Start the host and the web console:
      systemctl --user enable --now punktfunk-host punktfunk-web
  The console's login password:
      sed -n 's/^PUNKTFUNK_UI_PASSWORD=//p' ~/.config/punktfunk/web-password
  Then open https://localhost:47992.

  For Steam Gaming Mode (gamescope) or the virtual Steam Deck pad, also join 'punktfunk'.
  It can emulate any USB device, so only do this on a machine you trust:
      sudo usermod -aG punktfunk "$USER"
EOF
    fi
    if installed punktfunk-client; then
        echo "  The client is in your app menu as Punktfunk, or run: punktfunk-client"
    fi
    if [ "$NEED_RELOGIN" = 1 ]; then
        warn "You were added to the 'input' group. Log out and back in before streaming gamepads."
    fi
    echo "  Updates: sh install.sh update   (moss sync alone skips the setup steps above)"
}

do_update() {
    have_repo || die "The '$REPO_NAME' repo isn't set up. Run: sh install.sh install"
    say "Updating"
    as_root moss -y sync -u
    NEED_RELOGIN=0
    post_steps
    restart_units
    say "Up to date."
}

do_uninstall() {
    say "Removing punktfunk"
    [ -x /usr/libexec/punktfunk/door-remove ] && { as_root /usr/libexec/punktfunk/door-remove || true; }
    as_root systemctl --global disable punktfunk-scripting.service >/dev/null 2>&1 || true
    PKGS=""
    for p in punktfunk punktfunk-host punktfunk-client punktfunk-web punktfunk-scripting \
             punktfunk-seats punktfunk-bun punktfunk-icons; do
        installed "$p" && PKGS="$PKGS $p"
    done
    if [ -n "$PKGS" ]; then
        # shellcheck disable=SC2086
        as_root moss -y pkg remove $PKGS
    fi
    if have_repo; then
        as_root moss repo remove "$REPO_NAME"
    fi
    say "Removed. Your settings in ~/.config/punktfunk are kept."
}

case "$CMD" in
    install)   do_install ;;
    update)    do_update ;;
    uninstall) do_uninstall ;;
esac
