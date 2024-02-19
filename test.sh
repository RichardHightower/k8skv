
source env.sh

curl "${BASE_URL}"

curl -X POST -H "Content-Type: application/json" \
    -d '{"key":"value"}' "$BASE_URL"


curl "$BASE_URL"
