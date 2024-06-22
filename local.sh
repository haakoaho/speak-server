git checkout main
git pull 
git submodule update --init --recursive --remote

source ~/.bashrc


echo "Starting backend..."
cd /path/to/your/meeting-planner/backend
gradle bootRun &

echo "Starting frontend..."
cd /path/to/your/meeting-planner/frontend
npm install
npm start &

wait