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


# Start backend session
echo "Starting backend..."
cd ../speak-server/backend
gradle bootRun &
