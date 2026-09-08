#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Pass #S (the session the key was pressed in) explicitly: from a run-shell
# context, `tmux display-message -p '#S'` resolves to the *first* session on
# the server, not the one that triggered the key.
tmux bind-key C run-shell "$CURRENT_DIR/scripts/safekill.sh #S"
tmux bind-key Q run-shell "$CURRENT_DIR/scripts/safekill.sh w #S"
