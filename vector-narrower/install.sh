#!/bin/bash
# install.sh - Production installer for vector-narrower.
# Summary: Installs the vector-narrower app and required flow dependencies.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ID="vector-narrower"
APP_REPO_RAW="https://raw.githubusercontent.com/kaisarcode/flows/slave/vector-narrower"
SYS_BIN_DIR="/usr/local/bin"
DEPS="kc-flow kc-ngr kc-emb kc-mmp kc-dmn"

# Prints an error and exits.
# @param $1 Error message.
# @return Does not return.
fail() {
    printf "Error: %s\n" "$1" >&2
    exit 1
}

# Fails when one remote asset is unavailable.
# @param $1 Asset name.
# @return Does not return.
fail_unavailable() {
    fail "Remote asset is not available: $1"
}

# Verifies that the installer is running on Linux.
# @return 0 on success.
require_linux() {
    [ "$(uname -s)" = "Linux" ] || fail "install.sh currently targets Linux only."
}

# Verifies tools.
# @return 0 on success.
require_tools() {
    command -v wget >/dev/null 2>&1 || fail "wget is required."
    command -v sudo >/dev/null 2>&1 || fail "sudo is required."
}

# Detects architecture.
# @return size_t Architecture string.
detect_arch() {
    case "$(uname -m)" in
        x86_64) printf "x86_64" ;;
        aarch64|arm64) printf "aarch64" ;;
        armv8*|arm64-v8a) printf "arm64-v8a" ;;
        *) fail "Unsupported architecture: $(uname -m)" ;;
    esac
}

# Installs dependencies.
# @param $1 Dependency name.
# @param $2 Local mode flag.
# @return 0 on success.
install_dep() {
    local dep="$1"
    local local_mode="$2"
    if [ "$local_mode" = "true" ] && [ -f "$APP_DIR/../../kc-core/kc-al0/install.sh" ]; then
        sudo bash "$APP_DIR/../../kc-core/kc-al0/install.sh" "$dep"
    else
        wget -qO- "https://raw.githubusercontent.com/kaisarcode/kc-core/master/kc-al0/install.sh" | sudo bash -s -- "$dep"
    fi
}

# Installs the application.
# @param $1 Local mode flag.
# @return 0 on success.
install_app() {
    local local_mode="$1"
    local tmp_dir

    if [ "$local_mode" = "true" ]; then
        [ -f "$APP_DIR/bin/$APP_ID" ] || fail "Launcher script not found at ./bin/$APP_ID."
        sudo install -m 0755 "$APP_DIR/bin/$APP_ID" "$SYS_BIN_DIR/$APP_ID"
        return 0
    fi

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wget -qO "$tmp_dir/$APP_ID" "${APP_REPO_RAW}/bin/${APP_ID}" || fail_unavailable "launcher script"
    sudo install -m 0755 "$tmp_dir/$APP_ID" "$SYS_BIN_DIR/$APP_ID"
}

# Entry point for the installer.
# @param $@ Script arguments.
# @return 0 on success.
main() {
    local local_mode="false"
    require_linux
    require_tools
    [ "${1:-}" = "--local" ] && local_mode="true"

    for dep in $DEPS; do
        install_dep "$dep" "$local_mode"
    done

    install_app "$local_mode"
    printf "%s installed.\n" "$APP_ID"
}

main "$@"
