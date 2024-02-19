from flask import Flask, request, jsonify
from kubernetes import client, config

app = Flask(__name__)

# Load Kubernetes configuration, in-cluster or from a Kubeconfig file
try:
    config.load_incluster_config()
except config.ConfigException:
    config.load_kube_config()

# Initialize Kubernetes API client
v1 = client.CoreV1Api()

# Function to get or create a ConfigMap
def get_or_create_cm(namespace, name):
    try:
        return v1.read_namespaced_config_map(name, namespace)
    except client.exceptions.ApiException as e:
        if e.status == 404:
            cm_body = client.V1ConfigMap(metadata=client.V1ObjectMeta(name=name))
            return v1.create_namespaced_config_map(namespace, cm_body)
        else:
            raise

# CRUD operations for ConfigMap K/V pairs
@app.route('/kv/<namespace>/<configmap>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def handle_kv(namespace, configmap):
    if request.method == 'GET':
        cm = get_or_create_cm(namespace, configmap)
        return jsonify(cm.data or {})
    elif request.method in ['POST', 'PUT']:
        kv = request.json
        cm = get_or_create_cm(namespace, configmap)
        if not cm.data:
            cm.data = {}
        cm.data.update(kv)
        v1.replace_namespaced_config_map(configmap, namespace, cm)
        return jsonify(cm.data)
    elif request.method == 'DELETE':
        key = request.args.get('key')
        cm = get_or_create_cm(namespace, configmap)
        if cm.data and key in cm.data:
            del cm.data[key]
            v1.replace_namespaced_config_map(configmap, namespace, cm)
            return jsonify(success=True)
        return jsonify(success=False), 404

# Service Discovery Endpoint
@app.route('/discover/<namespace>', methods=['GET'])
def discover_services(namespace):
    services = v1.list_namespaced_service(namespace)
    service_info = {s.metadata.name: s.spec.cluster_ip for s in services.items}
    return jsonify(service_info)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')
