#!/usr/bin/env bash

# Quick test setup to demonstrate the progress UI
progress() {
  local step="$1"
  local message="$2"
  local percent="${3:-0}"
  echo "PROGRESS:$step:$message:$percent"
}

progress "init" "Initializing AI system..." "5"
sleep 1

progress "engine" "Installing AI engine..." "10"
sleep 1
progress "engine" "AI engine installed successfully" "25"
sleep 1

progress "service" "Starting AI service..." "30"
sleep 1
progress "service" "AI service ready" "45"
sleep 1

progress "model" "Preparing AI intelligence..." "50"
sleep 1

# Simulate download progress
for i in {55..95..5}; do
    progress "model" "Downloading AI intelligence... ${i}%" "$i"
    sleep 0.5
done

progress "model" "Verifying AI intelligence..." "95"
sleep 1
progress "model" "AI intelligence ready" "100"
sleep 1

progress "complete" "AI system ready!" "100"