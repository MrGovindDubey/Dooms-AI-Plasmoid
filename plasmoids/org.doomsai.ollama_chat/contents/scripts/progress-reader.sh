#!/usr/bin/env bash

PROGRESS_FILE="/tmp/dooms-ai-progress.txt"
SETUP_PID_FILE="/tmp/dooms-ai-setup.pid"

# Function to read and output progress
read_progress() {
  if [[ -f "$PROGRESS_FILE" ]]; then
    cat "$PROGRESS_FILE"
    return 0
  fi
  return 1
}

# Check if setup is running
is_setup_running() {
  if [[ -f "$SETUP_PID_FILE" ]]; then
    if kill -0 "$(cat "$SETUP_PID_FILE")" 2>/dev/null; then
      return 0
    else
      rm -f "$SETUP_PID_FILE" "$PROGRESS_FILE"
      return 1
    fi
  fi
  return 1
}

# Main logic
if is_setup_running; then
  read_progress
else
  echo "PROGRESS:complete:Setup not running:0"
fi