# sourcing session
source ~/.bashrc

# git session
git checkout main
git pull
git submodule foreach --recursive git reset --hard
git submodule update --init --recursive --remote

# tmole session for port 8081
echo "Starting tmole forwarding for port 8081..."
nohup tmole 8081 > backend_tmole_output.txt 2>&1 &

# tmole session for port 3000
echo "Starting tmole forwarding for port 3000..."
nohup tmole 3000 > frontend_tmole_output.txt 2>&1 &
sleep 30  # Ensure tmole has time to initialize

BACKEND_URL=$(grep -o 'http://.*\.tunnelmole.net/' backend_tmole_output.txt | head -n 1)
FRONTEND_URL=$(grep -o 'http://.*\.tunnelmole.net/*' frontend_tmole_output.txt | head -n 1)

echo $BACKEND_URL
echo $FRONTEND_URL

# tmole to git session
cd ../speak-fun
DEPLOYMENTS_FILE="deployments.json"

git fetch origin
git reset --hard origin/main
jq --arg frontendUrl "$FRONTEND_URL" \
   --arg backendUrl "$BACKEND_URL" \
   '.frontendUrl = $frontendUrl | .backendUrl = $backendUrl' \
   "$DEPLOYMENTS_FILE" > tmp && mv tmp "$DEPLOYMENTS_FILE"

git add "$DEPLOYMENTS_FILE"
git commit -m "Update deployment URLs"
git push origin main 