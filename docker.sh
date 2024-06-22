git checkout main
git pull 

# Update submodules to their latest commits
git submodule update --init --recursive --remote

# Build and run the Docker containers
docker-compose down
docker-compose build
docker-compose up -d