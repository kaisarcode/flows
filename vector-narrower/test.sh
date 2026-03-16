#!/bin/bash
# test.sh - Automated test suite for vector-narrower
# Summary: Validates the vector-narrower app surface and internal consistency.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
APP_ROOT="$SCRIPT_DIR"
LAUNCHER="$APP_ROOT/bin/vector-narrower"
KCS_BIN="$APP_ROOT/../../kc-core/kcs"
KC_FLOW_BIN="$APP_ROOT/../../kc-core/kc-al1/kc-flow/bin/$(uname -m)/kc-flow"

# Fallback for kc-flow if not in expected relative path
if [ ! -x "$KC_FLOW_BIN" ]; then
    KC_FLOW_BIN=$(command -v kc-flow || true)
fi

# Prints one test failure and exits.
fail() {
    printf "\033[31m[FAIL]\033[0m %s\n" "$1"
    exit 1
}

# Prints one passing test message.
pass() {
    printf "\033[32m[PASS]\033[0m %s\n" "$1"
}

# Prepares the test runtime environment.
test_setup() {
    [ -x "$LAUNCHER" ] || fail "Launcher not found at $LAUNCHER"
    [ -n "$KC_FLOW_BIN" ] || fail "kc-flow not found. Please install it or ensure it is in ../../kc-core"
    export KC_FLOW_BIN
    pass "Environment verified: using $KC_FLOW_BIN"
}

# Runs KCS validation.
test_kcs() {
    if [ -x "$KCS_BIN" ]; then
        find "$APP_ROOT/src" -type f -not -path '*/.*' -exec "$KCS_BIN" {} + || fail "KCS validation failed."
        find "$APP_ROOT/bin" -maxdepth 1 -type f -not -path '*/.*' -exec "$KCS_BIN" {} + || fail "KCS validation failed on bin/."
        pass "KCS compliance verified."
    else
        pass "KCS: validator not found at $KCS_BIN, skipping."
    fi
}

# Builds stub runtime tools for functional tests.
build_stub_bin() {
    stub_root="$1"
    
    # Stub for kc-emb
    cat > "$stub_root/kc-emb" <<'EOF'
#!/bin/bash
set -e
MODE="generate"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --mode) MODE="$2"; shift 2 ;;
        --fd-in) FD_IN="$2"; shift 2 ;;
        --fd-out) FD_OUT="$2"; shift 2 ;;
        *) shift ;;
    esac
done
if [ -n "$FD_IN" ]; then exec 0<"/proc/self/fd/$FD_IN"; fi
if [ -n "$FD_OUT" ]; then exec 1>"/proc/self/fd/$FD_OUT"; fi
emit_vec() {
    case "$1" in
        hello*) printf '[1.0,0.0,0.0]\n' ;;
        pasta*) printf '[0.0,1.0,0.0]\n' ;;
        *) printf '[0.0,0.0,0.0]\n' ;;
    esac
}
if [ "$MODE" = "generate" ]; then
    while IFS= read -r line; do [ -n "$line" ] || continue; emit_vec "$line"; done
    exit 0
fi
while IFS= read -r A; do
    IFS= read -r B || exit 1
    if [ "$A" = "$B" ]; then printf '1.0\n'; else printf '0.0\n'; fi
done
EOF

    # Stub for kc-ngr
    cat > "$stub_root/kc-ngr" <<'EOF'
#!/bin/bash
set -e
while [ "$#" -gt 0 ]; do
    case "$1" in
        --fd-in) FD_IN="$2"; shift 2 ;;
        --fd-out) FD_OUT="$2"; shift 2 ;;
        *) shift ;;
    esac
done
if [ -n "$FD_IN" ]; then exec 0<"/proc/self/fd/$FD_IN"; fi
if [ -n "$FD_OUT" ]; then exec 1>"/proc/self/fd/$FD_OUT"; fi
while IFS= read -r line; do [ -n "$line" ] || continue; printf '%s\n' "$line"; done
EOF

    # Stub for kc-mmp
    cat > "$stub_root/kc-mmp" <<'EOF'
#!/bin/bash
set -e
while [ "$#" -gt 0 ]; do
    case "$1" in
        --map) MAP="$2"; shift 2 ;;
        --mode) MODE="$2"; shift 2 ;;
        --fd-in) FD_IN="$2"; shift 2 ;;
        --fd-out) FD_OUT="$2"; shift 2 ;;
        *) shift ;;
    esac
done
case "$MODE" in
    set) if [ -n "$FD_IN" ]; then cat "/proc/self/fd/$FD_IN" > "$MAP"; else cat > "$MAP"; fi ;;
    get) if [ -n "$FD_OUT" ]; then cat "$MAP" > "/proc/self/fd/$FD_OUT"; else cat "$MAP"; fi ;;
esac
EOF

    # Stub for kc-dmn
    cat > "$stub_root/kc-dmn" <<'EOF'
#!/bin/bash
set -e
exec kc-emb "$@"
EOF

    chmod +x "$stub_root/kc-emb" "$stub_root/kc-ngr" "$stub_root/kc-mmp" "$stub_root/kc-dmn"
}

# Runs functional pack/match tests using the launcher.
test_functional() {
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' RETURN

    build_stub_bin "$TMP_DIR"
    export PATH="$TMP_DIR:$PATH"

    # 1. Test Pack
    cat > "$TMP_DIR/input.txt" <<'EOF'
hello world
hello world
cooking pasta
EOF
    "$LAUNCHER" pack --store "$TMP_DIR/store.bin" --model fake.gguf --dim 3 --fd-in 0 < "$TMP_DIR/input.txt" > /dev/null
    
    [ -s "$TMP_DIR/store.bin" ] || fail "Pack: store was not created."
    grep -Fq $'hello world\t[1.0,0.0,0.0]' "$TMP_DIR/store.bin" || fail "Pack: data missing from store."
    pass "App 'pack' command verified."

    # 2. Test Match
    OUTPUT=$(echo "hello world" | "$LAUNCHER" match --store "$TMP_DIR/store.bin" --model fake.gguf --dim 3 --threshold 0.5)
    
    # We expect 'hello world' repeated because we had it twice in input and stub match matches everything identical.
    # Actually the stub 'match' only emits 1.0 if identical.
    # vnw-score-select might filter.
    [ -n "$OUTPUT" ] || fail "Match: produced no output."
    echo "$OUTPUT" | grep -q "hello world" || fail "Match: expected 'hello world', got '$OUTPUT'"
    pass "App 'match' command verified."

    # 3. Test FD Handling
    exec 3<<<"cooking pasta"
    OUTPUT=$("$LAUNCHER" match --store "$TMP_DIR/store.bin" --model fake.gguf --dim 3 --threshold 0.5 --fd-in 3)
    exec 3<&-
    echo "$OUTPUT" | grep -q "cooking pasta" || fail "FD: --fd-in 3 failed."
    pass "FD handling verified."

    # 4. Invalid FD
    if "$LAUNCHER" pack --store "$TMP_DIR/s.bin" --fd-in 99 2>/dev/null; then
        fail "Invalid FD should fail."
    fi
    pass "Invalid FD fails correctly."

}

main() {
    test_setup
    test_kcs
    test_functional
    pass "All tests passed."
}

main "$@"
