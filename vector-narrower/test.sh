#!/bin/bash
# test.sh - Automated test suite for vector-narrower
# Summary: Validates the kc-flow replacement for kc-vnw with stubbed utilities.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
APP_ROOT="$SCRIPT_DIR"
FLOW_ROOT="$SCRIPT_DIR/src/flow"
KC_FLOW_ROOT="$SCRIPT_DIR/../../kc-core/kc-al1/kc-flow"
KCS_BIN="$SCRIPT_DIR/../../kc-core/kcs"

# Prints one test failure and exits.
# @param $1 Failure message.
# @return Does not return.
fail() {
    printf "\033[31m[FAIL]\033[0m %s\n" "$1"
    exit 1
}

# Prints one passing test message.
# @param $1 Success message.
# @return 0 on success.
pass() {
    printf "\033[32m[PASS]\033[0m %s\n" "$1"
}

# Prepares the test runtime environment.
# @return 0 on success.
test_setup() {
    ARCH=$(uname -m)
    [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "aarch64" ] || ARCH="arm64-v8a"
    export KC_BIN_EXEC="$KC_FLOW_ROOT/bin/$ARCH/kc-flow"

    [ -x "$KC_BIN_EXEC" ] || fail "kc-flow binary not found at $KC_BIN_EXEC."
    pass "Environment verified: using $KC_BIN_EXEC"
}

# Runs KCS validation across the module.
# @return 0 on success.
test_kcs() {
    if [ -x "$KCS_BIN" ]; then
        find "$APP_ROOT" -type f -not -path '*/.*' \
            -exec "$KCS_BIN" {} + || fail "KCS validation failed."
        pass "General: KCS compliance verified."
    fi
}

# Builds stub runtime tools for functional flow tests.
# @param $1 Stub binary root path.
# @return 0 on success.
build_stub_bin() {
    stub_root="$1"
    printf '%s\n' \
        '#!/bin/bash' \
        'set -e' \
        'MODE="generate"' \
        "while [ \"\$#\" -gt 0 ]; do" \
        "    case \"\$1\" in" \
        "        --mode) MODE=\"\$2\"; shift 2 ;;" \
        '        --dim|--model) shift 2 ;;' \
        "        --fd-in) FD_IN=\"\$2\"; shift 2 ;;" \
        "        --fd-out) FD_OUT=\"\$2\"; shift 2 ;;" \
        '        *) shift ;;' \
        '    esac' \
        'done' \
        "if [ -n \"\$FD_IN\" ]; then exec 7<\"/proc/self/fd/\$FD_IN\"; else exec 7<&0; fi" \
        "if [ -n \"\$FD_OUT\" ]; then exec 8>\"/proc/self/fd/\$FD_OUT\"; else exec 8>&1; fi" \
        'emit_vec() {' \
        "    case \"\$1\" in" \
        "        hello*|rome*) printf '[1.0,0.0,0.0]\\n' >&8 ;;" \
        "        pasta*|cook*) printf '[0.0,1.0,0.0]\\n' >&8 ;;" \
        "        ai*|industry*) printf '[0.0,0.0,1.0]\\n' >&8 ;;" \
        "        *) printf '[0.0,0.0,0.0]\\n' >&8 ;;" \
        '    esac' \
        '}' \
        "if [ \"\$MODE\" = \"generate\" ]; then" \
        "    while IFS= read -r line <&7; do [ -n \"\$line\" ] || continue; emit_vec \"\$line\"; done" \
        '    exit 0' \
        'fi' \
        "while IFS= read -r A <&7; do" \
        '    IFS= read -r B <&7 || exit 1' \
        "    if [ \"\$A\" = \"\$B\" ]; then printf '1.0\\n' >&8; else printf '0.0\\n' >&8; fi" \
        'done' \
        > "$stub_root/kc-emb"

    printf '%s\n' \
        '#!/bin/bash' \
        'set -e' \
        "while [ \"\$#\" -gt 0 ]; do" \
        "    case \"\$1\" in" \
        "        --fd-in) FD_IN=\"\$2\"; shift 2 ;;" \
        "        --fd-out) FD_OUT=\"\$2\"; shift 2 ;;" \
        '        *) shift ;;' \
        '    esac' \
        'done' \
        "if [ -n \"\$FD_IN\" ]; then exec 7<\"/proc/self/fd/\$FD_IN\"; else exec 7<&0; fi" \
        "if [ -n \"\$FD_OUT\" ]; then exec 8>\"/proc/self/fd/\$FD_OUT\"; else exec 8>&1; fi" \
        "while IFS= read -r line <&7; do [ -n \"\$line\" ] || continue; printf '%s\\n' \"\$line\" >&8; done" \
        > "$stub_root/kc-ngr"

    printf '%s\n' \
        '#!/bin/bash' \
        'set -e' \
        "while [ \"\$#\" -gt 0 ]; do" \
        "    case \"\$1\" in" \
        "        --map) MAP=\"\$2\"; shift 2 ;;" \
        "        --mode) MODE=\"\$2\"; shift 2 ;;" \
        "        --fd-in) FD_IN=\"\$2\"; shift 2 ;;" \
        "        --fd-out) FD_OUT=\"\$2\"; shift 2 ;;" \
        '        *) shift ;;' \
        '    esac' \
        'done' \
        "[ -n \"\$MAP\" ] || exit 1" \
        "[ -n \"\$MODE\" ] || exit 1" \
        "if [ \"\$MODE\" = \"set\" ]; then" \
        "    if [ -n \"\$FD_IN\" ]; then cat \"/proc/self/fd/\$FD_IN\" > \"\$MAP\"; else cat > \"\$MAP\"; fi" \
        '    exit 0' \
        'fi' \
        "if [ \"\$MODE\" = \"get\" ]; then" \
        "    [ -f \"\$MAP\" ] || exit 1" \
        "    if [ -n \"\$FD_OUT\" ]; then cat \"\$MAP\" > \"/proc/self/fd/\$FD_OUT\"; else cat \"\$MAP\"; fi" \
        '    exit 0' \
        'fi' \
        'exit 1' \
        > "$stub_root/kc-mmp"

    printf '%s\n' '#!/bin/bash' 'set -e' 'cat' > "$stub_root/kc-dmn"
    printf '%s\n' \
        '#!/bin/bash' \
        'set -e' \
        'SOCKET=""' \
        "while [ \"\$#\" -gt 0 ]; do" \
        "    case \"\$1\" in" \
        "        --socket) SOCKET=\"\$2\"; shift 2 ;;" \
        '        --until|--status|--stop) shift ;;' \
        '        --) shift; break ;;' \
        '        *) shift ;;' \
        '    esac' \
        'done' \
        "case \"\$SOCKET\" in" \
        '    *score*) exec kc-emb --mode cosine-similarity --dim 3 ;;' \
        '    *) exec kc-emb --dim 3 ;;' \
        'esac' \
        > "$stub_root/kc-dmn"

    chmod +x "$stub_root/kc-emb" "$stub_root/kc-ngr" "$stub_root/kc-mmp" "$stub_root/kc-dmn"
}

# Runs functional pack/match coverage against stubbed tools.
# @return 0 on success.
test_pack_and_match() {
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' RETURN

    build_stub_bin "$TMP_DIR"
    export PATH="$TMP_DIR:$PATH"

    cat > "$TMP_DIR/input.txt" <<'EOF'
hello world
cooking pasta
EOF

    exec 3<"$TMP_DIR/input.txt"
    "$KC_BIN_EXEC" --run "$FLOW_ROOT/vnw-pack.flow" \
        --fd-in 3 \
        --set flow.param.store.path="$TMP_DIR/store.bin" \
        --set flow.param.emb.model=fake.gguf \
        --set flow.param.emb.dim=3 \
        --set flow.param.work.source_path="$TMP_DIR/pack.source" \
        >/dev/null
    exec 3<&-

    [ -s "$TMP_DIR/store.bin" ] || fail "Pack: store was not created."
    if ! grep -Fq $'hello world\t[1.0,0.0,0.0]' "$TMP_DIR/store.bin"; then
        fail "Pack: first record missing from store."
    fi
    if ! grep -Fq $'cooking pasta\t[0.0,1.0,0.0]' "$TMP_DIR/store.bin"; then
        fail "Pack: second record missing from store."
    fi
    pass "Pack flow verified."

    exec 3<<<"hello world"
    OUTPUT=$("$KC_BIN_EXEC" --run "$FLOW_ROOT/vnw-match.flow" \
        --fd-in 3 \
        --set flow.param.store.path="$TMP_DIR/store.bin" \
        --set flow.param.emb.model=fake.gguf \
        --set flow.param.emb.dim=3 \
        --set flow.param.ngr.max_tokens=3 \
        --set flow.param.select.threshold=0.5 \
        --set flow.param.work.query_path="$TMP_DIR/query.txt" \
        --set flow.param.work.segments_path="$TMP_DIR/segments.txt" \
        --set flow.param.work.embeddings_path="$TMP_DIR/embeddings.txt")
    exec 3<&-

    [ "$OUTPUT" = "hello world" ] || fail "Match: expected 'hello world', got '$OUTPUT'."
    pass "Match flow verified."

    exec 3<<<"hello world"
    OUTPUT=$("$KC_BIN_EXEC" --run "$FLOW_ROOT/vnw-match.flow" \
        --fd-in 3 \
        --set flow.param.store.path="$TMP_DIR/store.bin" \
        --set flow.param.emb.socket="$TMP_DIR/embed.sock" \
        --set flow.param.score.socket="$TMP_DIR/score.sock" \
        --set flow.param.emb.dim=3 \
        --set flow.param.ngr.max_tokens=3 \
        --set flow.param.select.threshold=0.5 \
        --set flow.param.work.query_path="$TMP_DIR/query-daemon.txt" \
        --set flow.param.work.segments_path="$TMP_DIR/segments-daemon.txt" \
        --set flow.param.work.embeddings_path="$TMP_DIR/embeddings-daemon.txt")
    exec 3<&-

    [ "$OUTPUT" = "hello world" ] || fail "Match daemon: expected 'hello world', got '$OUTPUT'."
    pass "Match daemon scoring verified."

    exec 3<"$TMP_DIR/input.txt"
    OUTPUT=$("$KC_BIN_EXEC" --run "$FLOW_ROOT/vector-narrower.flow" \
        --fd-in 3 \
        --set flow.param.mode=pack \
        --set flow.param.store.path="$TMP_DIR/store-2.bin" \
        --set flow.param.emb.model=fake.gguf \
        --set flow.param.emb.dim=3 \
        --set flow.param.work.source_path="$TMP_DIR/pack-2.source" \
        --set flow.param.work.query_path="$TMP_DIR/query-2.txt" \
        --set flow.param.work.segments_path="$TMP_DIR/segments-2.txt" \
        --set flow.param.work.embeddings_path="$TMP_DIR/embeddings-2.txt")
    exec 3<&-

    [ -s "$TMP_DIR/store-2.bin" ] || fail "Unified flow: pack mode did not create the store."
    [ -n "$OUTPUT" ] || fail "Unified flow: pack mode produced no terminal output."

    exec 3<<<"cooking pasta"
    OUTPUT=$("$KC_BIN_EXEC" --run "$FLOW_ROOT/vector-narrower.flow" \
        --fd-in 3 \
        --set flow.param.mode=match \
        --set flow.param.store.path="$TMP_DIR/store-2.bin" \
        --set flow.param.emb.model=fake.gguf \
        --set flow.param.emb.dim=3 \
        --set flow.param.select.threshold=0.5 \
        --set flow.param.work.source_path="$TMP_DIR/pack-3.source" \
        --set flow.param.work.query_path="$TMP_DIR/query-3.txt" \
        --set flow.param.work.segments_path="$TMP_DIR/segments-3.txt" \
        --set flow.param.work.embeddings_path="$TMP_DIR/embeddings-3.txt")
    exec 3<&-

    [ "$OUTPUT" = "cooking pasta" ] || fail "Unified flow: expected 'cooking pasta', got '$OUTPUT'."
    pass "Unified flow verified."

    rm -rf "$TMP_DIR"
    trap - RETURN
}

# Runs the automated test suite.
# @return 0 on success.
run_tests() {
    test_setup
    test_kcs
    test_pack_and_match
    pass "All tests passed successfully."
}

run_tests
