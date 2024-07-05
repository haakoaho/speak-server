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

TEMP_FILE=$(mktemp)
pkill -f tunnelmole
tmux kill-session -t speak-fun-deployment-backend

tmux new-session -d -s speak-fun-deployment-backend
tmux send-keys "tmole 8081 > $TEMP_FILE 2>&1" C-m  # Capture output to shared temporary file

# Wait for a few seconds to allow TunnelMole to capture the URL
sleep 10  # Adjust the sleep time as needed

# Capture the URL from the temporary file
BACKEND_URL=$(grep -o "https://.*tunnelmole.net" $TEMP_FILE | head -n 1)

rm $TEMP_FILE

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
