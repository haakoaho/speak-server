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
sleep 20  # Ensure ngrok has time to initialize

# Debugging step: Check if ngrok is running
if ! pgrep ngrok > /dev/null; then
  echo "ngrok is not running. Exiting..."
  exit 1
fi

# Fetch public URLs from ngrok API
NGROK_API_RESPONSE=$(curl -s http://localhost:4040/api/tunnels)
echo "ngrok API response: $NGROK_API_RESPONSE"  # Debugging step: Print API response

NEXT_PUBLIC_BACKEND_URL=$(echo $NGROK_API_RESPONSE | jq -r '.tunnels[] | select(.config.addr=="http://localhost:8081") | .public_url')
FRONTEND_URL=$(echo $NGROK_API_RESPONSE | jq -r '.tunnels[] | select(.config.addr=="http://localhost:3000") | .public_url')

# Check if URLs were fetched successfully
if [ -z "$NEXT_PUBLIC_BACKEND_URL" ]; then
  echo "Failed to fetch backend URL from ngrok."
else
  echo "Backend URL: $NEXT_PUBLIC_BACKEND_URL"
fi

if [ -z "$FRONTEND_URL" ]; then
  echo "Failed to fetch frontend URL from ngrok."
else
  echo "Frontend URL: $FRONTEND_URL"
fi

# Start the backend service
echo "Starting backend..."
cd backend
gradle bootRun &

# Start the frontend service
echo "Starting frontend..."
cd ../frontend
npm run start &

# Wait for both services to complete
wait
