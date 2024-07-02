#!/bin/bash

# Sourcing session (if required)
# source ~/.bashrc  # Uncomment if you need to source your .bashrc file

# Git session
git checkout main
git pull
git submodule foreach --recursive git reset --hard
git submodule update --init --recursive --remote

# Stop running backend service session (if necessary)
if lsof -i tcp:8081 -t > /dev/null; then
  echo "Port 8081 is already in use. Stopping the process..."
  gradle --stop
fi

# TunnelMole session for port 8081
echo "Starting TunnelMole forwarding for port 8081..."
pkill -f tunnelmole  # Ensure no leftover TunnelMole processes

# Option 1: Subprocesses and Waiting (controlled execution)
tunnelmole_command="tmole 8081"  # Replace with your actual command
$tunnelmole_command &> backend_tmole_output.txt &
tunnelmole_pid=$!

# Option 2: Conditional Execution (if session established)
# tunnelmole_command="tmole 8081"  # Replace with your actual command
# $tunnelmole_command &> backend_tmole_output.txt

# Extract session URL (using robust grep for both options)
sleep 15  # Ensure TunnelMole has time to initialize (adjust if needed)
BACKEND_URL=$(grep -Eo "https://[^\"]+" backend_tmole_output.txt | head -n 1)

# Check if session URL was captured successfully (applicable to both options)
if [[ -z "$BACKEND_URL" ]]; then
  echo "Error: Failed to capture TunnelMole session URL. Please check 'backend_tmole_output.txt' for details."
  exit 1
fi

# Option 1: Wait for TunnelMole process to finish (if using subprocesses)
wait $tunnelmole_pid

echo

# tmole to git session
cd ../speak-fun
DEPLOYMENTS_FILE="deployments.json"

git fetch origin
git reset --hard origin/main
jq --arg backendUrl "$BACKEND_URL" \
  '.backendUrl = $backendUrl' \
  "$DEPLOYMENTS_FILE" > tmp && mv tmp "$DEPLOYMENTS_FILE"

git add "$DEPLOYMENTS_FILE"
git commit -m "Update backend deployment URL"
git push origin main &  # Run in the background

# Start backend session
echo "Starting backend..."
cd ../speak-server/backend
gradle bootRun &

# Optional cleanup
rm backend_tmole_output.txt