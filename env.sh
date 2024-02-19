export SERVICE_HOST=localhost
export SERVICE_PORT=5001
export BASE_URL=http://${SERVICE_HOST}:${SERVICE_PORT}/kv/default/configmap


export SERVICE_NAME="k8skv"
export VERSION="v0.1"
export IMAGE="${SERVICE_NAME}:${VERSION}"
export DOCKER_REPO=richardhightower

