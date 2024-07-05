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

# tmole session for port 3000
echo "Starting tmole forwarding for port 3000..."
tmole 3000 > frontend_tmole_output.txt 2>&1 &
sleep 15  # Ensure tmole has time to initialize
FRONTEND_URL=$(grep -o 'http://.*\.tunnelmole.net/' frontend_tmole_output.txt | head -n 1)
pkill -f tunnelmole

# tmole to git session
cd ../speak-fun
DEPLOYMENTS_FILE="deployments.json"

git reset --hard
jq --arg frontendUrl "$FRONTEND_URL" \
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
echo "Starting frontend..."
cd ../frontend
npm install
npm run start &

wait # Wait for frontend service to complete
