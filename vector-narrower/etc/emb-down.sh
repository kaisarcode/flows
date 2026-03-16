#!/bin/bash
# emb-down.sh - Example embedding daemon stopper for vector-narrower.
# Summary: Stops the example kc-emb daemon socket.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

DEFAULT_SOCKET_PATH="/tmp/vector-narrower-emb.sock"
SOCKET_PATH="${EMB_SOCKET:-$DEFAULT_SOCKET_PATH}"

# Stops the example embedding daemon.
# @return 0 on success.
main() {
    kc-dmn --socket "$SOCKET_PATH" --stop
}

main "$@"
