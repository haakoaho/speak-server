#!/bin/bash

# sourcing session
source ~/.bashrc

# git session
git checkout main
git pull
git submodule foreach --recursive git reset --hard
git submodule update --init --recursive --remote

# stop running backend service session
if lsof -i tcp:8081 -t > /dev/null; then
  echo "Port 8081 is already in use. Stopping the process..."
  gradle --stop
fi

# ensure no other tmole instances are running
pkill -f tunnelmole

# tmole session for port 8081
echo "Starting tmole forwarding for port 8081..."
tmole 8081 > backend_tmole_output.txt 2>&1 &
sleep 15  # Ensure tmole has time to initialize
BACKEND_URL=$(grep -o 'http://.*\.tunnelmole.net/' backend_tmole_output.txt | head -n 1)
pkill -f tunnelmole

# tmole to git session
cd ../speak-fun
DEPLOYMENTS_FILE="deployments.json"

git reset --hard
jq --arg backendUrl "$BACKEND_URL" \
   '.backendUrl = $backendUrl' \
   "$DEPLOYMENTS_FILE" > tmp && mv tmp "$DEPLOYMENTS_FILE"

git add "$DEPLOYMENTS_FILE"
git commit -m "Update backend deployment URL"
git push origin main

# start backend session
echo "Starting backend..."
cd ../backend
gradle bootRun &
