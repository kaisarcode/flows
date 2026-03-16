#!/bin/bash
# example.sh - Local example runner for vector-narrower.
# Summary: Packs a small sample corpus and runs one local match query.
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
DEFAULT_QUERY_PATH="$SCRIPT_DIR/example-query.txt"
MODEL_PATH="${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
CORPUS_PATH="${CORPUS_PATH:-$DEFAULT_CORPUS_PATH}"
QUERY_PATH="${QUERY_PATH:-$DEFAULT_QUERY_PATH}"
STORE_PATH="${STORE_PATH:-/tmp/vector-narrower.example.store}"
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
    [ -f "$QUERY_PATH" ] || fail "Example query not found at $QUERY_PATH."
}

# Runs one example pack operation.
# @param $1 Corpus path.
# @return 0 on success.
run_pack() {
    exec 3<"$1"
    run_quiet "$ENTRYPOINT" \
        --fd-in 3 \
        --set flow.param.mode=pack \
        --set flow.param.store.path="$STORE_PATH" \
        --set flow.param.emb.model="$MODEL_PATH" \
        --set flow.param.emb.dim="$EMB_DIM" \
        --set flow.param.work.source_path="$PACK_SOURCE_PATH" \
        >/dev/null
    exec 3<&-
}

# Runs one example match operation.
# @param $1 Query text.
# @return 0 on success.
run_match() {
    exec 3<<<"$1"
    run_quiet "$ENTRYPOINT" \
        --fd-in 3 \
        --set flow.param.mode=match \
        --set flow.param.store.path="$STORE_PATH" \
        --set flow.param.emb.model="$MODEL_PATH" \
        --set flow.param.emb.dim="$EMB_DIM" \
        --set flow.param.ngr.max_tokens=5 \
        --set flow.param.select.threshold=0.7 \
        --set flow.param.work.query_path="$MATCH_QUERY_PATH" \
        --set flow.param.work.segments_path="$MATCH_SEGMENTS_PATH" \
        --set flow.param.work.embeddings_path="$MATCH_EMBEDDINGS_PATH"
    exec 3<&-
}

# Runs the example entry point.
# @return 0 on success.
main() {
    PACK_SOURCE_PATH="$(mktemp)"
    MATCH_QUERY_PATH="$(mktemp)"
    MATCH_SEGMENTS_PATH="$(mktemp)"
    MATCH_EMBEDDINGS_PATH="$(mktemp)"
    trap 'rm -f "$PACK_SOURCE_PATH" "$MATCH_QUERY_PATH" "$MATCH_SEGMENTS_PATH" "$MATCH_EMBEDDINGS_PATH"' EXIT

    require_runtime
    run_pack "$CORPUS_PATH"

    printf "Stored sample corpus in %s\n" "$STORE_PATH"
    printf "Query result:\n"
    run_match "$(cat "$QUERY_PATH")"
}

main "$@"
