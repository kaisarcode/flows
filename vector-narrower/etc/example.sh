#!/bin/bash
# example.sh - Practical demonstration of vector-narrower
# Summary: Build a small vector store and perform semantic matches using bge-small.
#
# Author: KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

# Prepares the temporary vector store and executes semantic queries.
# @param $1 Path to the GGUF model.
# @param $2 Path to the vector-narrower launcher.
# @return 0 on success.
run_example() {
    model_path="$1"
    vnw_bin="$2"
    tmp_dir="$(mktemp -d)"
    sock="$tmp_dir/vnw.sock"

    cleanup() {
        kc-dmn --socket "$sock" --stop >/dev/null 2>&1 || true
        rm -rf "$tmp_dir"
    }

    trap cleanup EXIT

    printf "The history of Rome is complex and fascinating.\n" > "$tmp_dir/data.txt"
    printf "Artificial Intelligence is transforming world industry.\n" >> "$tmp_dir/data.txt"
    printf "Cooking pasta requires boiling water and salt.\n" >> "$tmp_dir/data.txt"

    SECONDS=0
    printf "\n\033[1;34m[STEP 1]\033[0m Building Vector Store with BGE-Small...\n"
    "$vnw_bin" pack \
        --store "$tmp_dir/kb.store" \
        --model "$model_path" \
        --dim 384 \
        < "$tmp_dir/data.txt"
    printf "\033[1;30m[TIME: %ss]\033[0m\n" "${SECONDS}"

    printf "\n\033[1;34m[STEP 2]\033[0m Starting persistent embedding daemon (kc-dmn)...\n"
    kc-dmn --socket "$sock" --start kc-emb -- --model "$model_path" --dim 384

    SECONDS=0
    printf "\n\033[1;34m[STEP 3]\033[0m Natural Language Query: \033[32m\"AI and modern industry\"\033[0m\n"
    printf "\n\033[1;33m[RESULTS]\033[0m\n"
    echo "AI and modern industry" \
        | "$vnw_bin" match \
            --store "$tmp_dir/kb.store" \
            --emb-socket "$sock" \
            --dim 384 \
            --threshold 0.7 \
        | sort -u
    printf "\033[1;30m[TIME: %ss]\033[0m\n" "${SECONDS}"

    SECONDS=0
    printf "\n\033[1;34m[STEP 4]\033[0m Natural Language Query: \033[32m\"How to cook italian food\"\033[0m\n"
    printf "\n\033[1;33m[RESULTS]\033[0m\n"
    echo "How to cook italian food" \
        | "$vnw_bin" match \
            --store "$tmp_dir/kb.store" \
            --emb-socket "$sock" \
            --dim 384 \
            --threshold 0.7 \
        | sort -u
    printf "\033[1;30m[TIME: %ss]\033[0m\n" "${SECONDS}"

    SECONDS=0
    printf "\n\033[1;34m[STEP 5]\033[0m Natural Language Query: \033[32m\"Ancient empires\"\033[0m\n"
    printf "\n\033[1;33m[RESULTS]\033[0m\n"
    echo "Ancient empires" \
        | "$vnw_bin" match \
            --store "$tmp_dir/kb.store" \
            --emb-socket "$sock" \
            --dim 384 \
            --threshold 0.5 \
        | sort -u
    printf "\033[1;30m[TIME: %ss]\033[0m\n" "${SECONDS}"
}

# Main entry point.
# @return 0 on success.
main() {
    script_dir="$(CDPATH='' cd -- "$(dirname "$0")" && pwd)"
    model="$script_dir/bge-small.gguf"
    bin="$script_dir/../bin/vector-narrower"

    [ -f "$model" ] || {
        printf "Error: Model not found at %s\n" "$model" >&2
        exit 1
    }

    [ -x "$bin" ] || {
        printf "Error: vector-narrower not found at %s\n" "$bin" >&2
        exit 1
    }

    command -v kc-dmn >/dev/null 2>&1 || {
        printf "Error: kc-dmn not found in PATH.\n" >&2
        exit 1
    }

    command -v kc-emb >/dev/null 2>&1 || {
        printf "Error: kc-emb not found in PATH.\n" >&2
        exit 1
    }

    run_example "$model" "$bin"
}

main "$@"