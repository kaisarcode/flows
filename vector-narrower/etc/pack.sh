#!/bin/bash
# pack.sh - Example pack runner for vector-narrower.
# Summary: Packs the example corpus into one vector store.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
MODULE_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
ENTRYPOINT="$MODULE_ROOT/bin/vector-narrower"
DEFAULT_MODEL_PATH="$SCRIPT_DIR/bge-small.gguf"
DEFAULT_CORPUS_PATH="$SCRIPT_DIR/example-corpus.txt"
DEFAULT_STORE_PATH="$SCRIPT_DIR/example.bin"
DEFAULT_SOCKET_PATH="/tmp/vector-narrower-emb.sock"
MODEL_PATH="${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
CORPUS_PATH="${CORPUS_PATH:-$DEFAULT_CORPUS_PATH}"
STORE_PATH="${STORE_PATH:-$DEFAULT_STORE_PATH}"
EMB_SOCKET="${EMB_SOCKET:-$DEFAULT_SOCKET_PATH}"
EMB_DIM="${EMB_DIM:-384}"

# Prints one fatal error and exits.
# @param $1 Error message.
# @return Does not return.
fail() {
    printf "Error: %s\n" "$1" >&2
    exit 1
}

# Runs one command quietly, preserving stderr only on failure.
# @param $@ Command and args.
# @return 0 on success.
run_quiet() {
    stderr_path="$(mktemp)"
    if "$@" 2>"$stderr_path"; then
        rm -f "$stderr_path"
        return 0
    fi

    cat "$stderr_path" >&2
    rm -f "$stderr_path"
    return 1
}

# Verifies that runtime inputs are present.
# @return 0 on success.
require_runtime() {
    [ -x "$ENTRYPOINT" ] || fail "Entry point not found at $ENTRYPOINT."
    [ -f "$MODEL_PATH" ] || fail "Embedding model not found at $MODEL_PATH."
    [ -f "$CORPUS_PATH" ] || fail "Example corpus not found at $CORPUS_PATH."
}

# Runs one pack operation over the configured corpus.
# @return 0 on success.
main() {
    PACK_SOURCE_PATH="$(mktemp)"
    trap 'rm -f "$PACK_SOURCE_PATH"' EXIT

    require_runtime

    exec 3<"$CORPUS_PATH"
    run_quiet "$ENTRYPOINT" \
        --fd-in 3 \
        --set flow.param.mode=pack \
        --set flow.param.store.path="$STORE_PATH" \
        --set flow.param.emb.model="$MODEL_PATH" \
        --set flow.param.emb.socket="$EMB_SOCKET" \
        --set flow.param.emb.dim="$EMB_DIM" \
        --set flow.param.work.source_path="$PACK_SOURCE_PATH" \
        >/dev/null
    exec 3<&-
}

main "$@"
