#!/bin/bash
# match.sh - Example match runner for vector-narrower.
# Summary: Matches the example query against one vector store.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
MODULE_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
ENTRYPOINT="$MODULE_ROOT/bin/vector-narrower"
DEFAULT_MODEL_PATH="$SCRIPT_DIR/bge-small.gguf"
DEFAULT_QUERY_PATH="$SCRIPT_DIR/example-query.txt"
DEFAULT_STORE_PATH="$SCRIPT_DIR/example.bin"
DEFAULT_SOCKET_PATH="/tmp/vector-narrower-emb.sock"
MODEL_PATH="${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
QUERY_PATH="${QUERY_PATH:-$DEFAULT_QUERY_PATH}"
STORE_PATH="${STORE_PATH:-$DEFAULT_STORE_PATH}"
EMB_SOCKET="${EMB_SOCKET:-$DEFAULT_SOCKET_PATH}"
SCORE_SOCKET="${SCORE_SOCKET:-}"
EMB_DIM="${EMB_DIM:-384}"
NGR_MAX_TOKENS="${NGR_MAX_TOKENS:-5}"
SELECT_THRESHOLD="${SELECT_THRESHOLD:-0.7}"

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
    [ -f "$QUERY_PATH" ] || fail "Example query not found at $QUERY_PATH."
    [ -f "$STORE_PATH" ] || fail "Vector store not found at $STORE_PATH."
}

# Returns one active embedding socket when available.
# @return 0 on success.
resolve_emb_socket() {
    if [ -n "$EMB_SOCKET" ] && kc-dmn --socket "$EMB_SOCKET" --status >/dev/null 2>&1; then
        printf "%s\n" "$EMB_SOCKET"
        return 0
    fi
    printf "\n"
}

# Runs one match operation over the configured query.
# @return 0 on success.
main() {
    MATCH_QUERY_PATH="$(mktemp)"
    MATCH_SEGMENTS_PATH="$(mktemp)"
    MATCH_EMBEDDINGS_PATH="$(mktemp)"
    active_emb_socket="$(resolve_emb_socket)"
    trap 'rm -f "$MATCH_QUERY_PATH" "$MATCH_SEGMENTS_PATH" "$MATCH_EMBEDDINGS_PATH"' EXIT

    require_runtime
    query_text="$(cat "$QUERY_PATH")"

    exec 3<<<"$query_text"
    result="$(
        run_quiet "$ENTRYPOINT" \
            --fd-in 3 \
            --set flow.param.mode=match \
            --set flow.param.store.path="$STORE_PATH" \
            --set flow.param.emb.model="$MODEL_PATH" \
            --set flow.param.emb.socket="$active_emb_socket" \
            --set flow.param.score.socket="$SCORE_SOCKET" \
            --set flow.param.emb.dim="$EMB_DIM" \
            --set flow.param.ngr.max_tokens="$NGR_MAX_TOKENS" \
            --set flow.param.select.threshold="$SELECT_THRESHOLD" \
            --set flow.param.work.query_path="$MATCH_QUERY_PATH" \
            --set flow.param.work.segments_path="$MATCH_SEGMENTS_PATH" \
            --set flow.param.work.embeddings_path="$MATCH_EMBEDDINGS_PATH"
    )"
    exec 3<&-
    printf "%s\n" "$result"
}

main "$@"
