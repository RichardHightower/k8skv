source env.sh
echo "Building the Docker image..."
docker build --platform linux/amd64 -t ${DOCKER_REPO}/$IMAGE .
docker push ${DOCKER_REPO}/$IMAGE