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
MODEL_PATH="${MODEL_PATH:-}"
STORE_PATH="${STORE_PATH:-/tmp/vector-narrower.example.store}"
EMB_DIM="${EMB_DIM:-384}"

# Prints one fatal error and exits.
# @param $1 Error message.
# @return Does not return.
fail() {
    printf "Error: %s\n" "$1" >&2
    exit 1
}

# Verifies that runtime inputs are present.
# @return 0 on success.
require_runtime() {
    [ -x "$ENTRYPOINT" ] || fail "Entry point not found at $ENTRYPOINT."
    [ -n "$MODEL_PATH" ] || fail "Set MODEL_PATH to one GGUF embedding model path."
}

# Writes one example source corpus.
# @param $1 Output path.
# @return 0 on success.
write_sample_corpus() {
    cat > "$1" <<'EOF'
rome travel guide
cooking pasta
ai industry trends
EOF
}

# Runs one example pack operation.
# @param $1 Corpus path.
# @return 0 on success.
run_pack() {
    exec 3<"$1"
    "$ENTRYPOINT" \
        --fd-in 3 \
        --set flow.param.mode=pack \
        --set flow.param.store.path="$STORE_PATH" \
        --set flow.param.emb.model="$MODEL_PATH" \
        --set flow.param.emb.dim="$EMB_DIM" \
        >/dev/null
    exec 3<&-
}

# Runs one example match operation.
# @param $1 Query text.
# @return 0 on success.
run_match() {
    exec 3<<<"$1"
    "$ENTRYPOINT" \
        --fd-in 3 \
        --set flow.param.mode=match \
        --set flow.param.store.path="$STORE_PATH" \
        --set flow.param.emb.model="$MODEL_PATH" \
        --set flow.param.emb.dim="$EMB_DIM" \
        --set flow.param.ngr.max_tokens=5 \
        --set flow.param.select.threshold=0.7
    exec 3<&-
}

# Runs the example entry point.
# @return 0 on success.
main() {
    corpus_path="$(mktemp)"
    trap 'rm -f "$corpus_path"' EXIT

    require_runtime
    write_sample_corpus "$corpus_path"
    run_pack "$corpus_path"

    printf "Stored sample corpus in %s\n" "$STORE_PATH"
    printf "Query result:\n"
    run_match "how to cook pasta"
}

main "$@"
