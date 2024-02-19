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
