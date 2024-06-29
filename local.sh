# sourcing session
source ~/.bashrc

# git session
git checkout main
git pull
git submodule foreach --recursive git reset --hard
git submodule update --init --recursive --remote

# stop running services session
if lsof -i tcp:8081 -t > /dev/null; then
  echo "Port 8081 is already in use. Stopping the process..."
  gradle --stop
fi

if lsof -i tcp:3000 -t > /dev/null; then
  echo "Port 3000 is already in use. Stopping the process..."
  PID=$(lsof -i tcp:3000 -t -p)
  kill -9 $PID
fi

# tmole session for port 8081
echo "Starting tmole forwarding for port 8081..."
BACKEND_TMOLE_OUTPUT=$(tmole 8081)
BACKEND_URL=$(echo "$BACKEND_TMOLE_OUTPUT" | grep -o 'http://[^ ]*' | head -n 1)

# tmole session for port 3000
echo "Starting tmole forwarding for port 3000..."
FRONTEND_TMOLE_OUTPUT=$(tmole 3000)
FRONTEND_URL=$(echo "$FRONTEND_TMOLE_OUTPUT" | grep -o 'http://[^ ]*' | head -n 1)

# tmole to git session
cd ../speak-fun
DEPLOYMENTS_FILE="deployments.json"

git reset --hard
jq --arg frontendUrl "$FRONTEND_URL" \
   --arg backendUrl "$BACKEND_URL" \
   '.frontendUrl = $frontendUrl | .backendUrl = $backendUrl' \
   "$DEPLOYMENTS_FILE" > tmp && mv tmp "$DEPLOYMENTS_FILE"

git add "$DEPLOYMENTS_FILE"
git commit -m "Update deployment URLs"
git push origin main &

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

# start backend session
echo "Starting backend..."
cd ../backend
gradle bootRun &

# start frontend session
echo "Starting frontend..."
cd ../frontend
npm install
npm run start &

wait # Wait for both services to complete
