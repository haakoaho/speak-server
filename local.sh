git checkout main
git pull 
git submodule update --init --recursive --remote

source ~/.bashrc


echo "Starting backend..."
cd backend
gradle bootRun &

echo "Starting frontend..."
cd ../frontend
npm run build
npm run start &

wait