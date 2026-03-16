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

if [ ! -x "$KC_FLOW_BIN" ]; then
    KC_FLOW_BIN=$(command -v kc-flow || true)
fi

# Prints one test failure and exits.
# @param $1 Error message.
# @return Does not return.
fail() {
    printf "\033[31m[FAIL]\033[0m %s\n" "$1"
    exit 1
}

# Prints one passing test message.
# @param $1 Success message.
# @return 0.
pass() {
    printf "\033[32m[PASS]\033[0m %s\n" "$1"
    return 0
}

# Prepares the test runtime environment.
# @return 0 on success.
test_setup() {
    [ -x "$LAUNCHER" ] || fail "Launcher not found at $LAUNCHER"
    [ -n "$KC_FLOW_BIN" ] || fail "kc-flow not found. Please install it or ensure it is in ../../kc-core"
    export KC_FLOW_BIN
    pass "Environment verified: using $KC_FLOW_BIN"
    return 0
}

# Runs KCS validation.
# @return 0 on success.
test_kcs() {
    if [ -x "$KCS_BIN" ]; then
        find "$APP_ROOT/src" -type f -not -path '*/.*' -exec "$KCS_BIN" {} + || fail "KCS validation failed."
        find "$APP_ROOT/bin" -maxdepth 1 -type f -not -path '*/.*' -exec "$KCS_BIN" {} + || fail "KCS validation failed on bin/."
        "$KCS_BIN" "$APP_ROOT/install.sh" || fail "KCS validation failed on install.sh."
        "$KCS_BIN" "$APP_ROOT/test.sh" || fail "KCS validation failed on test.sh."
        pass "KCS compliance verified."
    else
        pass "KCS: validator not found at $KCS_BIN, skipping."
    fi
    return 0
}

# Builds stub runtime tools for functional tests.
# @param $1 Stub root directory.
# @return 0 on success.
build_stub_bin() {
    local stub_root="$1"
    
    printf '#!/bin/bash\nset -e\nMODE="generate"\n' > "$stub_root/kc-emb"
    cat >> "$stub_root/kc-emb" <<'EOF'
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

    printf '#!/bin/bash\nset -e\n' > "$stub_root/kc-ngr"
    cat >> "$stub_root/kc-ngr" <<'EOF'
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

    printf '#!/bin/bash\nset -e\n' > "$stub_root/kc-mmp"
    cat >> "$stub_root/kc-mmp" <<'EOF'
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

    printf '#!/bin/bash\nset -e\nexec kc-emb "$@"\n' > "$stub_root/kc-dmn"

    chmod +x "$stub_root/kc-emb" "$stub_root/kc-ngr" "$stub_root/kc-mmp" "$stub_root/kc-dmn"
    return 0
}

# Runs functional pack/match tests using the launcher.
# @return 0 on success.
test_functional() {
    local tmp_dir
    local output
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    build_stub_bin "$tmp_dir"
    export PATH="$tmp_dir:$PATH"

    cat > "$tmp_dir/input.txt" <<'EOF'
hello world
hello world
cooking pasta
EOF
    "$LAUNCHER" pack --store "$tmp_dir/store.bin" --model fake.gguf --dim 3 --fd-in 0 < "$tmp_dir/input.txt" > /dev/null
    
    [ -s "$tmp_dir/store.bin" ] || fail "Pack: store was not created."
    grep -Fq $'hello world\t[1.0,0.0,0.0]' "$tmp_dir/store.bin" || fail "Pack: data missing from store."
    pass "App 'pack' command verified."

    output=$(echo "hello world" | "$LAUNCHER" match --store "$tmp_dir/store.bin" --model fake.gguf --dim 3 --threshold 0.5)
    
    [ -n "$output" ] || fail "Match: produced no output."
    echo "$output" | grep -q "hello world" || fail "Match: expected 'hello world', got '$output'"
    pass "App 'match' command verified."

    exec 3<<<"cooking pasta"
    output=$("$LAUNCHER" match --store "$tmp_dir/store.bin" --model fake.gguf --dim 3 --threshold 0.5 --fd-in 3)
    exec 3<&-
    echo "$output" | grep -q "cooking pasta" || fail "FD: --fd-in 3 failed."
    pass "FD handling verified."

    if "$LAUNCHER" pack --store "$tmp_dir/s.bin" --fd-in 99 2>/dev/null; then
        fail "Invalid FD should fail."
    fi
    pass "Invalid FD fails correctly."

    return 0
}

# Entry point for the test suite.
# @param $@ Script arguments.
# @return 0 on success.
main() {
    test_setup
    test_kcs
    test_functional
    pass "All tests passed."
    return 0
}

main "$@"
