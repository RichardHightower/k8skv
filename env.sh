# export SERVICE_HOST=localhost
export SERVICE_HOST=4.255.115.172
export SERVICE_PORT=5001
export KEY=demo
export BASE_URL=http://${SERVICE_HOST}:${SERVICE_PORT}/kv/default/$KEY

export SERVICE_NAME="k8skv"
export VERSION="v0.3"
export IMAGE="${SERVICE_NAME}:${VERSION}"
export DOCKER_REPO=richardhightower

