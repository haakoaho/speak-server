#!/bin/bash

# sourcing session
source ~/.bashrc

# git session
git checkout main
git pull
git submodule foreach --recursive git reset --hard
git submodule update --init --recursive --remote

# stop running frontend service session
if lsof -i tcp:3000 -t > /dev/null; then
  echo "Port 3000 is already in use. Stopping the process..."
  PID=$(lsof -i tcp:3000 -t -p)
  kill -9 $PID
fi

# ensure no other tmole instances are running
pkill -f tunnelmole
tmux kill-session -t speak-fun-deployment-frontend

TEMP_FILE=$(mktemp)

# tmole session for port 3000
echo "Starting tmole forwarding for port 3000..."
tmux new-session -d -s speak-fun-deployment-frontend
tmux send-keys "tmole 3000 > $TEMP_FILE 2>&1" C-m  # Capture output to shared temporary file

# Wait for a few seconds to allow TunnelMole to capture the URL
sleep 10  # Adjust the sleep time as needed

# Capture the URL from the temporary file
NEXTAUTH_URL=$(grep -o 'https://.*\.tunnelmole.net' $TEMP_FILE | head -n 1)
rm $TEMP_FILE

# tmole to git session
cd ../speak-fun
DEPLOYMENTS_FILE="deployments.json"

git fetch origin
git reset --hard origin/main
jq --arg frontendUrl "$NEXTAUTH_URL" \
   '.frontendUrl = $frontendUrl' \
   "$DEPLOYMENTS_FILE" > tmp && mv tmp "$DEPLOYMENTS_FILE"

git add "$DEPLOYMENTS_FILE"
git commit -m "Update frontend deployment URL"
git push origin main

# download next build session
cd ../speak-server/frontend
REPO_OWNER="haakoaho"
REPO_NAME="mobile-speak"
ARTIFACT_NAME="next-build"

RUN_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runs \
  | jq -r '.workflow_runs[] | select(.head_branch == "main") | .id' | head -n 1)

ARTIFACT_URL=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runs/$RUN_ID/artifacts \
  | jq -r ".artifacts[] | select(.name == \"$ARTIFACT_NAME\") | .archive_download_url")

curl -L -H "Authorization: token $GITHUB_TOKEN" -o artifact.zip $ARTIFACT_URL
rm -r .next
mkdir -p .next
unzip artifact.zip -d .next

# start frontend session
export NEXTAUTH_URL=$NEXTAUTH_URL

echo "Starting frontend..."
npm install
npm run start
