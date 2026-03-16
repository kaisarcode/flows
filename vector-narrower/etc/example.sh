#!/bin/bash
# example.sh - Combined example runner for vector-narrower.
# Summary: Runs the example pack and match scripts in sequence.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
EMB_UP_SCRIPT="$SCRIPT_DIR/emb-up.sh"
EMB_DOWN_SCRIPT="$SCRIPT_DIR/emb-down.sh"
PACK_SCRIPT="$SCRIPT_DIR/pack.sh"
MATCH_SCRIPT="$SCRIPT_DIR/match.sh"

# Prints one fatal error and exits.
# @param $1 Error message.
# @return Does not return.
fail() {
    printf "Error: %s\n" "$1" >&2
    exit 1
}

# Verifies that required scripts are present.
# @return 0 on success.
require_runtime() {
    [ -x "$EMB_UP_SCRIPT" ] || fail "Embed up script not found at $EMB_UP_SCRIPT."
    [ -x "$EMB_DOWN_SCRIPT" ] || fail \
        "Embed down script not found at $EMB_DOWN_SCRIPT."
    [ -x "$PACK_SCRIPT" ] || fail "Pack script not found at $PACK_SCRIPT."
    [ -x "$MATCH_SCRIPT" ] || fail "Match script not found at $MATCH_SCRIPT."
}

# Runs the example entry point.
# @return 0 on success.
main() {
    require_runtime
    "$EMB_DOWN_SCRIPT" >/dev/null 2>&1 || true
    trap '"$EMB_DOWN_SCRIPT" >/dev/null 2>&1 || true' EXIT
    "$EMB_UP_SCRIPT" >/dev/null
    "$PACK_SCRIPT"
    "$MATCH_SCRIPT"
}

main "$@"
