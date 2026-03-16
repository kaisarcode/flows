#!/bin/bash
# emb-up.sh - Example embedding daemon starter for vector-narrower.
# Summary: Starts one kc-emb daemon for the example model.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
DEFAULT_MODEL_PATH="$SCRIPT_DIR/bge-small.gguf"
DEFAULT_SOCKET_PATH="/tmp/vector-narrower-emb.sock"
MODEL_PATH="${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
SOCKET_PATH="${EMB_SOCKET:-$DEFAULT_SOCKET_PATH}"
EMB_DIM="${EMB_DIM:-384}"

# Prints one fatal error and exits.
# @param $1 Error message.
# @return Does not return.
fail() {
    printf "Error: %s\n" "$1" >&2
    exit 1
}

# Verifies daemon runtime inputs.
# @return 0 on success.
require_runtime() {
    [ -f "$MODEL_PATH" ] || fail "Embedding model not found at $MODEL_PATH."
}

# Starts the example embedding daemon.
# @return 0 on success.
main() {
    require_runtime
    kc-dmn --socket "$SOCKET_PATH" --start \
        "kc-emb --model \"$MODEL_PATH\" --dim $EMB_DIM"
}

main "$@"
