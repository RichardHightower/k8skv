
BASE_URL=http://${SERVICE_HOST}:${SERVICE_PORT}/kv/namespace/configmap

curl BASE_URL

curl -X POST -H "Content-Type: application/json" \
    -d '{"key":"value"}' BASE_URL


curl BASE_URL
