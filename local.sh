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
  PID=$(lsof -i tcp:8081 -t -p)
  kill -9 $PID
fi

# Frontend port check (similar logic for port 3000)
if lsof -i tcp:3000 -t > /dev/null; then
  echo "Port 3000 is already in use. Stopping the process..."
  PID=$(lsof -i tcp:3000 -t -p)
  kill -9 $PID
fi

# Start ngrok tunnels
echo "Starting ngrok for backend (port 8081)..."
nohup ngrok http 8081 > ngrok_backend.log &

echo "Starting ngrok for frontend (port 3000)..."
nohup ngrok http 3000 > ngrok_frontend.log &

# Wait for ngrok to initialize
sleep 5

# Print the public URLs from ngrok
echo "Backend URL:"
grep -o "https://[0-9a-z]*\.ngrok\.io" ngrok_backend.log

echo "Frontend URL:"
grep -o "https://[0-9a-z]*\.ngrok\.io" ngrok_frontend.log

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