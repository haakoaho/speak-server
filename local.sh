#!/bin/bash

# Pull the latest code and update submodules
git checkout main
git pull
git submodule foreach --recursive git reset --hard
git submodule update --init --recursive --remote

source ~/.bashrc

# Check for existing processes
# Backend port check
if lsof -i tcp:8081 -t > /dev/null; then
  echo "Port 8081 is already in use. Stopping the process..."
  gradle --stop
fi

# Frontend port check (similar logic for port 3000)
if lsof -i tcp:3000 -t > /dev/null; then
  echo "Port 3000 is already in use. Stopping the process..."
  PID=$(lsof -i tcp:3000 -t -p)
  kill -9 $PID
fi

# Start ngrok tunnels
echo "Starting ngrok forwarding..."
nohup ngrok start --all > /dev/null 2>&1 &


# Wait for ngrok to initialize
sleep 15  # Ensure ngrok has time to initialize

# Fetch public URLs from ngrok API
NGROK_API_RESPONSE=$(curl -s http://localhost:4040/api/tunnels)

BACKEND_URL=$(echo $NGROK_API_RESPONSE | jq -r '.tunnels[] | select(.config.addr=="http://localhost:8081") | .public_url')
FRONTEND_URL=$(echo $NGROK_API_RESPONSE | jq -r '.tunnels[] | select(.config.addr=="http://localhost:3000") | .public_url')

cd ../speak-fun
DEPLOYMENTS_FILE="deployments.json"

git reset --hard
# Update the JSON file with new URLs
jq --arg frontendUrl "$FRONTEND_URL" \
   --arg backendUrl "$BACKEND_URL" \
   '.frontendUrl = $frontendUrl | .backendUrl = $backendUrl' \
   "$DEPLOYMENTS_FILE" > tmp && mv tmp "$DEPLOYMENTS_FILE"

git add "$DEPLOYMENTS_FILE"
git commit -m "Update deployment URLs"
git push origin main &


# Start the backend service
echo "Starting backend..."
cd ../speak-server/backend
gradle bootRun &

# Start the frontend service
echo "Starting frontend..."
cd ../frontend
NEXT_PUBLIC_BACKEND_URL=$NEXT_PUBLIC_BACKEND_URL npm run start
 &

# Wait for both services to complete
wait
