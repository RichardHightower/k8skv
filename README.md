# k8skv
Example using service proxy to serve of K8s ConfigMaps

Debug container 
kubectl exec -it k8skv-deployment-67b84d7777-9s8hd -- /bin/bash

# K8s KV example

There is a need to store K/V values for DCM clients for feature flags and service discovery (SD). I do not 100% understand the SD requirements.

At the core of K8s is etcd which uses the same sort of consensus algorithm as Consul does. Etcd is what K8s uses for service discovery and storing config maps, etc. They are competitors with similar features. Consul can be used in non K8s environments and is very mature. There is a lot of overlap in what Consul provides and what is provided by K8s in conjunction with etcd. They both provide SD, K/V consistent stores, health checks, etc. These features are bespoke in K8s and well-managed and integrated. In Consul, there would be a lot of manual config and/or code integration to provide what is already provided by K8s.

## TLDR

Use the K8s REST API. Delegate to it from a simple service proxy that is exposed via ingress to the client. This code should be less than 100 lines of code for a K/V lookup. For SD, it might be more but if you manage SD in Consul then you also have to manage health checks in Consul, which is both a duplication of effort and complex.

**Bullet points**

The Kubernetes API allows for direct interaction with its resources, including ConfigMaps and Secrets. You can perform CRUD (Create, Read, Update, Delete) operations on these objects through REST calls. This capability can be leveraged to expose configuration data via a REST endpoint, albeit with some considerations:

- **Custom API Service**: To expose a specific REST endpoint that interacts with ConfigMaps or Secrets, you would typically want to develop a custom service that runs within your Kubernetes cluster. This service would act as a middle layer, handling HTTP requests from outside the cluster and translating them into the appropriate Kubernetes API calls.
    - This is because you don’t want to expose the whole API and the RBAC solution for access to K8s services is still beta and not a well worn path
    - This could consist of a small Python flask service that relays calls to config map or provides a shortened version of what config map provides
    - **Note that Authentication and Authorization**: Direct access to the Kubernetes API, especially from outside the cluster, requires careful management of authentication and authorization. You would need to ensure that only authorized users can access or modify the configuration data, potentially using Kubernetes' Role-Based Access Control (RBAC) [mechanisms.](http://mechanisms.th/) The RBAC support for K8s API is nascent at best.
    - Delta: While this approach utilizes the built-in capabilities of Kubernetes, it introduces complexity in terms of developing and maintaining the custom service that exposes the REST endpoint.
        - The functionality is small
        - The code is fairly simple
        - Service could be written in under 100 lines of code
    - This is going to come down to what exactly do you want to expose and it is very likely that even for cases like service discovery (which is beyond ConfigMap), that you would either use a K8s approach or duplicate the functionality of K8s with Consul

### **Evaluating Consul**

Given this capability of Kubernetes, the choice between using Kubernetes' native features and Consul for key-value storage might come down to specific requirements and preferences:

- **Built-in REST API with Consul**: Consul provides a built-in HTTP API for its key-value store, which might reduce development and maintenance efforts compared to setting up a custom service in Kubernetes.
    - K8s also has a REST API but it is hard to protect that via RBAC which then you would need to create a small service delegate, but one could argue the same for Consul with the major caveat is Consul is not as an important critical member of the stack and provides a smaller attack vector than exposing the entire K8s API.
    - To get the full advantage of Consul service discovery, you would have to manage health checks with Consul as well. This would duplicate what you have in K8s.
    - The more you add to Consul, the more you will want to write a proxy service to hide it and reduce attack vector.
- **Advanced Features**: If the use case benefits from Consul's additional features like service discovery, health checking, and multi-datacenter support, Consul might still be the preferable option.
    - K8s also has health checking, and service discovery via Consul would require that backend services register which would duplicate the functionality of K8s.
    - As far as multi-datacenter support, if you do go this route, it is more advantageous to go with a service-mesh approach which can aggregate K8s clusters.
- **Simplicity and Kubernetes Integration**: For scenarios where the additional features of Consul are not required, or if minimizing operational complexity is a priority, leveraging Kubernetes' native capabilities and directly accessing its API might be more beneficial. This approach keeps all configurations within the Kubernetes ecosystem and utilizes existing knowledge and tooling. Otherwise you have two ways of doing everything.

### Recommendation

Write a simple proxy to the K8s API to expose key/value pairs and to expose a service discovery built into K8s when and where needed. We would need more requirements to build such a service, but a simple service to expose key/value pairs would be easy to demonstrate hitting the K8s API and exposing read access to ConfigMaps which are in **essence** a K/V store for configuration. If needed additional behavior, switch to Consul.

## Code example

### Command line version : main.py

```python
import argparse
from kubernetes import client, config

def create_configmap(api_instance, namespace, name, data):
    """
    Create a ConfigMap in the specified namespace.
    """
    body = client.V1ConfigMap(
        api_version="v1",
        kind="ConfigMap",
        metadata=client.V1ObjectMeta(name=name),
        data=data
    )
    api_instance.create_namespaced_config_map(namespace=namespace, body=body)
    print(f"ConfigMap {name} created in namespace {namespace}")

def get_configmap(api_instance, namespace, name):
    """
    Get and print the specified ConfigMap from the namespace.
    """
    cm = api_instance.read_namespaced_config_map(name, namespace)
    print(f"ConfigMap {name} in namespace {namespace}: {cm.data}")

def delete_configmap(api_instance, namespace, name):
    """
    Delete the specified ConfigMap from the namespace.
    """
    api_instance.delete_namespaced_config_map(name, namespace)
    print(f"ConfigMap {name} deleted from namespace {namespace}")

def main():
    # Parse arguments from the command line
    parser = argparse.ArgumentParser(description='Kubernetes ConfigMap Operations')
    parser.add_argument('--namespace', required=True, help='The namespace of the ConfigMap')
    parser.add_argument('--name', required=True, help='The name of the ConfigMap')
    parser.add_argument('--data', help='The data for the ConfigMap, as "key1=value1;key2=value2"', default="")
    args = parser.parse_args()

    # Convert data from "key1=value1;key2=value2" to a dictionary
    data_dict = dict(pair.split('=') for pair in args.data.split(';') if pair)

    # Load Kubernetes configuration
    try:
        config.load_incluster_config()
    except config.ConfigException:
        config.load_kube_config()

    # Initialize Kubernetes API client
    v1 = client.CoreV1Api()

    # Perform operations
    create_configmap(v1, args.namespace, args.name, data_dict)
    get_configmap(v1, args.namespace, args.name)
    delete_configmap(v1, args.namespace, args.name)

if __name__ == '__main__':
    main()
```

The provided code is a Python script that uses the Kubernetes API to manage ConfigMaps in a specified Kubernetes namespace. Utilizing the Kubernetes Python client library, it can create, retrieve, and delete ConfigMaps. The script is designed to be executed from the command line, taking arguments for the namespace, name, and data of the ConfigMap. Here's a breakdown of its functionality:

1. **Import Statements**: The script imports necessary modules from the `argparse` library for command-line argument parsing and from the `kubernetes` package, specifically the `client` and `config` modules for interacting with the Kubernetes API.
2. **Function Definitions**: There are four main functions defined in the script:
    - `create_configmap(api_instance, namespace, name, data)`: Creates a ConfigMap in the given namespace with the specified name and data. The data is passed as a dictionary.
    - `get_configmap(api_instance, namespace, name)`: Retrieves and prints the data of a ConfigMap specified by its name and namespace.
    - `delete_configmap(api_instance, namespace, name)`: Deletes a ConfigMap specified by its name from the given namespace.
    
    These functions encapsulate the operations that can be performed on ConfigMaps using the Kubernetes API, handling the creation, retrieval, and deletion of ConfigMap resources.
    
3. **The `main` Function**: This is the entry point of the script. It performs several steps:
    - Parses command-line arguments using `argparse.ArgumentParser` to get the namespace, name, and data for the ConfigMap. The data argument is expected to be a string of key-value pairs separated by semicolons (e.g., "key1=value1;key2=value2").
    - Converts the `data` argument from a semicolon-separated string to a Python dictionary.
    - Attempts to load Kubernetes configuration using `config.load_incluster_config()`, falling back to `config.load_kube_config()` if the former raises a `ConfigException`. This enables the script to run both inside a Kubernetes cluster (using in-cluster configuration) and outside of it (using a kubeconfig file).
    - Initializes a Kubernetes API client (`client.CoreV1Api()`).
    - Calls the functions defined earlier to create, retrieve, and then delete the ConfigMap with the provided details.
4. **Execution**: The script checks if it is the main module being run (`if __name__ == '__main__':`) and calls the `main()` function to execute the script logic based on the provided command-line arguments.

This script is a practical example of automating Kubernetes operations using the Python client library, demonstrating how to programmatically manage ConfigMap resources within a Kubernetes cluster. It showcases basic Kubernetes API interactions, error handling, and command-line interface creation for Kubernetes resource management tasks.

### Code Listing Flask/Web version of service configMap proxy: app.py

```python
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
    app.run(debug=True, host='0.0.0.0', port=5001)
```

The above code listing is a Flask application that we can deploy to K8s that provides a REST API for managing Kubernetes ConfigMaps. Here's a detailed breakdown of its functionality:

1. **Imports and Flask App Initialization**:
    - The script imports necessary modules from Flask for creating a web application and handling requests, and from the Kubernetes Python client to interact with Kubernetes clusters.
    - It initializes a Flask application instance.
2. **Kubernetes Configuration Loading**:
    - Attempts to load Kubernetes configuration for in-cluster use (when running inside a Kubernetes cluster). If this fails (due to not running inside a cluster), it falls back to loading the configuration from a Kubeconfig file, typically used for local development and testing.
3. **Kubernetes API Client Initialization**:
    - Initializes a Kubernetes API client (`CoreV1Api`) which is used to interact with the Kubernetes cluster for operations on resources like ConfigMaps and Services.
4. **Function to Get or Create ConfigMap** (`get_or_create_cm`):
    - This function attempts to retrieve a specified ConfigMap from a given namespace. If the ConfigMap does not exist (indicated by a 404 status code from the Kubernetes API), it creates a new ConfigMap with the provided name and returns it. If any other error occurs, the error is raised.
5. **CRUD Operations for ConfigMap Key/Value Pairs**:
    - Defines a route (`/kv/<namespace>/<configmap>`) that supports GET, POST, PUT, and DELETE methods to manage key/value pairs within a specified ConfigMap.
    - **GET**: Retrieves the entire data of the ConfigMap. If the ConfigMap doesn't exist, it's created with no data.
    - **POST/PUT**: Updates the ConfigMap with new key/value pairs from the request body. If the ConfigMap doesn't exist, it's created.
    - **DELETE**: Removes a specified key/value pair from the ConfigMap. The key to delete is specified as a query parameter.
6. **Service Discovery Endpoint**:
    - Defines a route (`/discover/<namespace>`) that provides a GET method for service discovery within a specified namespace. It lists all services in the namespace and returns their names and cluster IP addresses in a JSON format.
7. **Running the Flask Application**:
    - Specifies that the Flask application should run on all interfaces (`host='0.0.0.0'`) and on port 5001, with debug mode enabled.

This application leverages the Kubernetes Python client to perform operations on ConfigMaps, such as reading, creating, and updating, directly from HTTP requests. It also provides a simple service discovery mechanism, showcasing how Kubernetes resources can be managed and queried using a custom-built REST API. This could be particularly useful for dynamic configuration and service discovery in microservices architectures.

## Dockerfile

```python
# Use an official Python runtime as a parent image
FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install any needed packages specified in requirements.txt
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# For debugging
# RUN apt-get -y update; apt-get -y install net-tools procps curl

# Make port 5001 available to the world outside this container
EXPOSE 5001

# Define environment variable
ENV NAME k8skv

# Run app.py when the container launches
CMD ["python", "app.py"]
```

This Dockerfile outlines instructions for building a Docker image for a Python application. Let's break down the key components and their purpose:

1. **Base Image**:
    - `FROM python:3.11-slim`: This line specifies the base image for the Docker container. It uses a slim version of the official Python 3.11 Docker image. The slim version is a lighter variant that has most of the common packages and dependencies needed for running Python applications but with less overhead compared to the full image.
2. **Working Directory**:
    - `WORKDIR /app`: Sets the working directory inside the container to `/app`. Future commands will be run from this directory.
3. **Copying Files**:
    - `COPY . /app`: Copies the current directory contents (where the Dockerfile is located) into the `/app` directory inside the container. This includes the application source code and any other files located in the same directory as the Dockerfile.
    - `COPY requirements.txt /app/`: Specifically copies the `requirements.txt` file into `/app/`, ensuring it's available for the next step.
4. **Installing Dependencies**:
    - `RUN pip install --no-cache-dir -r requirements.txt`: Installs the Python dependencies specified in `requirements.txt` using pip, Python's package installer. The `-no-cache-dir` option is used to prevent caching the downloaded packages, which can help reduce the size of the Docker image.
5. **Debugging Tools (Commented Out)**:
    - The commented-out `RUN` command (`# RUN apt-get -y update; apt-get -y install net-tools procps curl`) is for installing additional debugging tools like `net-tools`, `procps`, and `curl`. These tools can be useful for troubleshooting network issues, process management, and making HTTP requests, respectively. This line is commented out, indicating it's optional and can be enabled if needed.
6. **Exposing Port**:
    - `EXPOSE 5001`: This command makes port 5001 available to the host and other containers. This is the port that the Flask application (assumed from the context) will listen on.
7. **Environment Variable**:
    - `ENV NAME k8skv`: Sets an environment variable `NAME` with the value `k8skv` inside the container. This could be used by the application for various purposes, such as configuration settings.
8. **Container Entrypoint**:
    - `CMD ["python", "app.py"]`: Specifies the default command to run when the container starts. In this case, it runs the Python application with `python app.py`.

This Dockerfile is structured to create a lightweight, efficient Docker image tailored for running a specific Python application, with provisions for easy debugging and configuration through environment variables.

### k8s.yaml

```python
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8skv-deployment
spec:
  replicas: 1  # Consider your scaling needs
  selector:
    matchLabels:
      app: k8skv
  template:
    metadata:
      labels:
        app: k8skv
    spec:
      containers:
      - name: k8skv
        image: richardhightower/k8skv:v0.3
        ports:
        - containerPort: 5001

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: k8skv-ingress
spec:
  ingressClassName: "nginx"
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: k8skv-server
                port:
                  number: 5001

---

apiVersion: v1
kind: Service
metadata:
  name: k8skv-server
spec:
  type: LoadBalancer
  ports:
  - name: http
    port: 5001
    targetPort: 5001
  selector:
    app: k8skv

---

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: configmap-reader
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: configmap-reader-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: default  # Assuming you're using the default service account
  namespace: default
roleRef:
  kind: Role
  name: configmap-reader
  apiGroup: rbac.authorization.k8s.io
```

This Kubernetes configuration file defines multiple resources for deploying an application (`k8skv`) within a Kubernetes cluster. It's structured as a YAML file containing definitions for a Deployment, Ingress, Service, Role, and RoleBinding. Here's a breakdown of each section:

1. **Deployment (`k8skv-deployment`)**:
    - **apiVersion**: `apps/v1` indicates the version of the API to use.
    - **kind**: `Deployment` specifies that this is a Deployment resource.
    - **metadata**: Contains metadata about the Deployment, such as its name `k8skv-deployment`.
    - **spec**: Describes the desired state of the Deployment, including:
        - **replicas**: Specifies the number of pod instances. It's set to 1 here, but you can adjust this based on scaling needs.
        - **selector**: Defines how the Deployment finds which Pods to manage. In this case, it matches labels with `app: k8skv`.
        - **template**: The template for the Pods the Deployment manages, including:
            - **metadata**: Contains labels for the Pod, matching the Deployment selector.
            - **spec**: Specifies the containers to run in the Pod, including the container name (`k8skv`), the Docker image to use (`richardhightower/k8skv:v0.3`), and the container port (`5001`).
2. **Ingress (`k8skv-ingress`)**:
    - **apiVersion**: `networking.k8s.io/v1` indicates the API version.
    - **kind**: `Ingress` defines an Ingress resource for managing external access to the services, typically HTTP.
    - **metadata**: Contains the name of the Ingress resource.
    - **spec**: Specifies the Ingress rules, including:
        - **ingressClassName**: Specifies the Ingress class, in this case, `nginx`, indicating an Nginx Ingress controller is used.
        - **rules**: Defines the rules for routing traffic, directing HTTP traffic to the path `/` to the `k8skv-server` Service on port `5001`.
3. **Service (`k8skv-server`)**:
    - **apiVersion**: `v1` indicates the core API version.
    - **kind**: `Service` defines a Service resource for exposing the application.
    - **metadata**: Contains the name of the Service.
    - **spec**: Describes the desired state of the Service, including:
        - **type**: `LoadBalancer` indicates that the Service should be exposed externally through a cloud provider's load balancer.
        - **ports**: Specifies the port configuration, exposing port `5001`.
        - **selector**: Matches labels to select the Pods to which traffic should be routed, in this case, `app: k8skv`.
4. **Role (`configmap-reader`)**:
    - **apiVersion**: `rbac.authorization.k8s.io/v1` for Role-Based Access Control (RBAC) resources.
    - **kind**: `Role` defines permissions within a namespace.
    - **metadata**: Includes the namespace (`default`) and name of the Role.
    - **rules**: Specifies the permissions, allowing operations (`get`, `list`, `watch`, `create`, `update`, `delete`) on `configmaps`.
5. **RoleBinding (`configmap-reader-binding`)**:
    - **apiVersion**: `rbac.authorization.k8s.io/v1` for RBAC resources.
    - **kind**: `RoleBinding` links the Role to users or ServiceAccounts.
    - **metadata**: Contains the name of the RoleBinding.
    - **subjects**: Lists the entities the Role is applied to, in this case, the `default` ServiceAccount in the `default` namespace.
    - **roleRef**: References the Role being bound, `configmap-reader`.

This configuration collectively sets up an application deployment, external access through an Ingress, service exposure, and appropriate permissions for managing ConfigMaps within the Kubernetes cluster.

### env.sh

```python
# export SERVICE_HOST=localhost
export SERVICE_HOST=4.255.115.172
export SERVICE_PORT=5001
export BASE_URL=http://${SERVICE_HOST}:${SERVICE_PORT}/kv/default/somekey

export SERVICE_NAME="k8skv"
export VERSION="v0.3"
export IMAGE="${SERVICE_NAME}:${VERSION}"
export DOCKER_REPO=richardhightower
```

### dockerize.sh

```python
source env.sh
echo "Building the Docker image..."
docker build --platform linux/amd64 -t ${DOCKER_REPO}/$IMAGE .
docker push ${DOCKER_REPO}/$IMAGE
```

### test.sh

```python
source env.sh

curl "${BASE_URL}"

curl -X POST -H "Content-Type: application/json" \
    -d '{"key":"value", "key2":"value2" }' "$BASE_URL"

curl "$BASE_URL"
```

These three bash scripts are part of a workflow for managing a Dockerized application, including setting environment variables, building and pushing Docker images, and testing the application's HTTP endpoints. Below is an explanation of each script:

### `env.sh`

This script sets several environment variables used across the other scripts:

- `SERVICE_HOST` is set to an IP address, indicating the host where the service is running or should be accessed. Initially, there's a commented-out line to use `localhost`, which is replaced by a specific IP address.
- `SERVICE_PORT` specifies the port on which the service listens, set to `5001`.
- `BASE_URL` constructs the base URL for accessing the service's endpoints, incorporating the host and port. It's tailored for accessing a specific key-value pair in the service.
- `SERVICE_NAME`, `VERSION`, and `IMAGE` variables are defined for Docker image tagging purposes. `IMAGE` combines `SERVICE_NAME` and `VERSION`.
- `DOCKER_REPO` specifies the Docker repository where the image will be stored, set to `richardhightower`.

### `dockerize.sh`

This script is responsible for building and pushing a Docker image:

- `source env.sh` imports the environment variables set in `env.sh`.
- The script then echoes a message indicating the start of the Docker image building process.
- `docker build --platform linux/amd64 -t ${DOCKER_REPO}/$IMAGE .` builds the Docker image with a specified tag (`${DOCKER_REPO}/$IMAGE`), explicitly targeting the `linux/amd64` platform, using the current directory (`.`) as the context.
- `docker push ${DOCKER_REPO}/$IMAGE` pushes the built image to the specified Docker repository.

### `test.sh`

This script is used for testing the application's endpoints:

- `source env.sh` imports the environment variables from `env.sh`.
- The first `curl "${BASE_URL}"` command likely attempts to retrieve the current value of `somekey` in the default namespace, using the base URL defined in `env.sh`.
- The second `curl` command uses a `POST` request to update or set values for `key` and `key2` at the same URL, indicating a key-value store's update operation. It sets the content type to `application/json` and includes JSON data with the new key-value pairs.
- The final `curl "${BASE_URL}"` command likely retrieves the updated values of `somekey`, demonstrating the effect of the `POST` operation.

Together, these scripts provide a streamlined process for deploying and testing a Dockerized application, from environment setup and Docker operations to verifying functionality through HTTP requests.
