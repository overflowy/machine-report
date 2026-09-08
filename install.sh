#!/usr/bin/env bash
# Installer for machine-report.
#
#   curl -fsSL https://raw.githubusercontent.com/overflowy/machine-report/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/overflowy/machine-report/main/install.sh | bash -s -- --uninstall
#
# Puts machine_report in ~/.local/bin and adds one line to your shell rc file
# so the report runs at the start of every interactive shell.

set -u

REPO="overflowy/machine-report"
VERSION="${MR_VERSION:-main}" # branch or tag to fetch from
INSTALL_DIR="${MR_INSTALL_DIR:-$HOME/.local/bin}"
INSTALL_PATH="$INSTALL_DIR/machine_report"
MARKER="# machine_report"                   # tags the rc line so --uninstall can find it
LINE_RE="^\\[ -t 1 \\] && \".*\" $MARKER\$" # matches only that exact line shape, whatever the path
LINE="[ -t 1 ] && \"$INSTALL_PATH\" $MARKER"

usage() {
    cat <<EOF
Usage: install.sh [--uninstall]

Install machine_report to $INSTALL_DIR and run it at the start of
every interactive shell (adds one line to your shell's rc file).

Options:
  --uninstall   Remove the installed script and the rc line
  -h, --help    Show this help

Environment:
  MR_INSTALL_DIR  install directory      (default: ~/.local/bin)
  MR_VERSION      branch or tag to fetch (default: main)
EOF
}

rc_file() { # startup file for the user's login shell
    case "${SHELL##*/}" in
    zsh) printf '%s' "${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash)
        if [ "$(uname -s)" = Darwin ]; then printf '%s' "$HOME/.bash_profile"; else printf '%s' "$HOME/.bashrc"; fi
        ;;
    *)
        printf 'error: unsupported shell "%s" (expected bash or zsh)\n' "${SHELL:-unset}" >&2
        return 1
        ;;
    esac
}

fetch_script() { # write machine_report.sh to $1: from the checkout if we are in one, else from GitHub
    local local_copy="" url
    # $0 is a real file only when run from a checkout; piped through bash it is just "bash".
    [ -f "$0" ] && local_copy="$(cd "$(dirname "$0")" && pwd -P)/machine_report.sh"
    if [ -n "$local_copy" ] && [ -f "$local_copy" ]; then
        cp "$local_copy" "$1" && printf 'Copied from %s\n' "$local_copy" >&2
        return
    fi
    url="https://raw.githubusercontent.com/$REPO/$VERSION/machine_report.sh"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$1" "$url"
    else
        printf 'error: need curl or wget to download %s\n' "$url" >&2
        return 1
    fi && printf 'Downloaded %s\n' "$url" >&2
}

install() {
    local rc tmp
    mkdir -p "$INSTALL_DIR" || exit 1
    tmp=$(mktemp "$INSTALL_DIR/.machine_report.XXXXXX") || exit 1
    if ! fetch_script "$tmp"; then
        rm -f "$tmp"
        printf 'error: could not fetch machine_report.sh\n' >&2
        exit 1
    fi
    if ! head -n 1 "$tmp" | grep -q '^#!.*bash'; then # a 404 page or similar would not have a shebang
        rm -f "$tmp"
        printf 'error: downloaded file does not look like the script\n' >&2
        exit 1
    fi
    chmod 755 "$tmp" && mv -f "$tmp" "$INSTALL_PATH" || exit 1
    printf 'Installed %s\n' "$INSTALL_PATH" >&2

    rc=$(rc_file) || {
        printf 'Add this line to your shell startup file by hand:\n  %s\n' "$LINE" >&2
        exit 1
    }
    if [ -f "$rc" ] && grep -q "$LINE_RE" "$rc"; then
        printf 'Already hooked into %s\n' "$rc" >&2
        return 0
    fi
    # Make sure we start on a fresh line without adding a blank one.
    if [ -s "$rc" ] && [ -n "$(tail -c 1 "$rc")" ]; then printf '\n' >>"$rc"; fi
    printf '%s\n' "$LINE" >>"$rc" || {
        printf 'error: could not write to %s\n' "$rc" >&2
        exit 1
    }
    printf 'Added to %s:\n  %s\nOpen a new shell to see it, or run: source %s\n' "$rc" "$LINE" "$rc" >&2
}

uninstall() {
    local rc tmp
    if [ -f "$INSTALL_PATH" ]; then
        rm -f "$INSTALL_PATH" && printf 'Removed %s\n' "$INSTALL_PATH" >&2
    fi
    rc=$(rc_file) || exit 1
    if ! [ -f "$rc" ] || ! grep -q "$LINE_RE" "$rc"; then
        printf 'Nothing to remove from %s\n' "$rc" >&2
        return 0
    fi
    # Filter into a temp file, then write back through the rc path so a
    # symlinked rc (dotfile managers) stays a symlink. Keep the temp copy if
    # the write-back fails, since by then the rc has been truncated.
    tmp=$(mktemp) || exit 1
    grep -v "$LINE_RE" "$rc" >"$tmp" # exits 1 when nothing is left, which is fine
    if ! cat "$tmp" >"$rc"; then
        printf 'error: could not write %s; your filtered rc is saved at %s\n' "$rc" "$tmp" >&2
        exit 1
    fi
    rm -f "$tmp"
    printf 'Removed from %s\n' "$rc" >&2
}

case "${1:-}" in
"") install ;;
--uninstall) uninstall ;;
-h | --help) usage ;;
*)
    printf 'error: unknown option "%s"\n\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac
