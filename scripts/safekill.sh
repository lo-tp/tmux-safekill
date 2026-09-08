#!/usr/bin/env bash
set -e

# Session is passed by the key binding (the session where the key was pressed).
# "w" (window-only variant) carries no session; fall back to the legacy behavior.
if [ "${1:-}" = "w" ]; then
  SESSION=""
else
  SESSION="${1:-}"
fi

# Returns 0 if the pane (by pane_pid) is running pi. Works even when pi is an
# npm install, where pane_current_command reports "node" instead of "pi".
function pane_runs_pi {
  local pid="$1" cmd child
  cmd=$(ps -ww -o command= -p "$pid" 2>/dev/null)
  if [[ "$cmd" =~ (^|/)(pi)([[:space:]]|$) || "$cmd" == *pi-coding-agent* ]]; then
    return 0
  fi
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    pane_runs_pi "$child" && return 0
  done
  return 1
}

function safe_end_procs {
  old_ifs="$IFS"
  IFS=$'\n'
  for pane_set in $1; do
    pane_id=$(echo "$pane_set" | awk -F " " '{print $1}')
    pane_proc=$(echo "$pane_set" | awk -F " " '{print tolower($2)}')
    pane_pid=$(echo "$pane_set" | awk -F " " '{print $3}')
    cmd="C-c"
    if [[ "$pane_proc" == "vim" ]] || [[ "$pane_proc" == "nvim" ]]; then
      cmd='":qa" Enter'
    elif [[ "$pane_proc" == "man" ]] || [[ "$pane_proc" == "less" ]]; then
      cmd='"q"'
    elif [[ "$pane_proc" == "bash" ]] || [[ "$pane_proc" == "zsh" ]] || [[ "$pane_proc" == "fish" ]]; then
      cmd='C-c C-u space "exit" Enter'
    elif [[ "$pane_proc" == "ssh" ]] || [[ "$pane_proc" == "vagrant" ]]; then
      cmd='Enter "~."'
    elif [[ "$pane_proc" == "psql" ]]; then
      cmd='Enter "\q"'
    elif [[ "$pane_proc" == "pi" ]] || pane_runs_pi "$pane_pid"; then
      # Escape x2: interrupt any running request, then run /quit
      cmd='Escape Escape "/quit" Enter'
    fi
    echo $cmd | xargs tmux send-keys -t "$pane_id"
  done
  IFS="$old_ifs"
}

function safe_kill_panes_of_current_session {
  # Prefer the session passed from the binding; fall back to the legacy
  # resolution (first session on the server) when none was given.
  if [ -n "$SESSION" ]; then
    session_name="$SESSION"
  else
    session_name=$(tmux display-message -p '#S')
  fi
  current_panes=$(tmux list-panes -a -F "#{pane_id} #{pane_current_command} #{pane_pid} #{session_name}\n" | grep "$session_name")

  SAVEIFS="$IFS"
  IFS=$'\n'
  array=($current_panes)
  # Restore IFS
  IFS=$SAVEIFS
  for (( i=0; i<${#array[@]}; i++ ))
  do
    safe_end_procs "${array[$i]}"
    sleep 0.8
  done
}

safe_kill_panes_of_current_session
safe_kill_panes_of_current_session
exit 0
