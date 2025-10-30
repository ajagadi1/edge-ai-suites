# Deploy with Helm

Use Helm to deploy Smart Intersection to a Kubernetes cluster.
This guide will help you:

- Add the Helm chart repository.
- Configure the Helm chart to match your deployment needs.
- Deploy and verify the application.

Helm simplifies Kubernetes deployments by streamlining configurations and
enabling easy scaling and updates. For more details, see
[Helm Documentation](https://helm.sh/docs/).

## Prerequisites

Before You Begin, ensure the following:

- **Kubernetes Cluster**: Ensure you have a properly installed and
configured Kubernetes cluster.
- **System Requirements**: Verify that your system meets the [minimum requirements](./system-requirements.md).
- **Tools Installed**: Install the required tools:
  - Kubernetes CLI (kubectl)
  - Helm 3 or later
- **cert-manager**: Will be installed as part of the deployment process (instructions provided below)

## Steps to Deploy

To deploy the Smart Intersection Sample Application, copy and paste the entire block of following commands into your terminal and run them:


### Step 1: Clone the Repository

Before you can deploy with Helm, you must clone the repository:

```bash
# Clone the repository
git clone https://github.com/open-edge-platform/edge-ai-suites.git

# Navigate to the Metro AI Suite directory
cd edge-ai-suites/metro-ai-suite/metro-vision-ai-app-recipe/
```

### Step 2: Configure Proxy Settings (If behind a proxy)

If you are deploying in a proxy environment, update the values.yaml file with your proxy settings before installation:

```bash
# Edit the values.yml file to add proxy configuration
nano ./smart-intersection/chart/values.yaml
```

Update the existing proxy configuration in your values.yaml with following values:

```yaml
http_proxy: "http://your-proxy-server:port"
https_proxy: "http://your-proxy-server:port"
no_proxy: "localhost,127.0.0.1,.local,.cluster.local"
```

Replace `your-proxy-server:port` with your actual proxy server details.

### Install cert-manager

The Smart Intersection application requires cert-manager for TLS certificate management. Install cert-manager before deploying the application:

```bash
# Install cert-manager using YAML manifests (recommended for reliability)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=Available --timeout=60s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=Available --timeout=60s deployment/cert-manager-webhook -n cert-manager
```

### Setup Storage Provisioner (For Single-Node Clusters)

Check if your cluster has a default storage class with dynamic provisioning. If not, install a storage provisioner:

```bash
# Check for existing storage classes
kubectl get storageclass

# If no storage classes exist or none are marked as default, install local-path-provisioner
# This step is typically needed for single-node bare Kubernetes installations
# (Managed clusters like EKS/GKE/AKS already have storage classes configured)

# Install local-path-provisioner for automatic storage provisioning
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Set it as default storage class
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Verify storage class is ready
kubectl get storageclass
```

### Step 3: Deploy the application

Now you're ready to deploy the Smart Intersection application:

```bash
# Install the chart (works on both single-node and multi-node clusters)
helm upgrade --install smart-intersection ./smart-intersection/chart \
  --create-namespace \
  --set grafana.service.type=NodePort \
  --set global.storageClassName="" \
  -n smart-intersection
```

> **Note**: Using `global.storageClassName=""` makes the deployment use whatever default storage class exists on your cluster. This works for both single-node and multi-node setups.

> **Note**: If you encounter any issues during deployment, see the [Troubleshooting Guide](./support.md#troubleshooting-helm-deployments) for detailed solutions.

## Access Application Services using Node Port

### Access the Application UI using Node Port

- Get the Node Port Number using following command and use it to access the Application UI

```bash
kubectl get service smart-intersection-web -n smart-intersection -o jsonpath='{.spec.ports[0].nodePort}'
```

- Go to https://<HOST_IP>:<Node_PORT>
- **Log in with credentials**:
  - **Username**: `admin`
  - **Password**: Stored in `supass` secret. To retrieve run the following command:

    ```bash
    kubectl get secret smart-intersection-supass-secret -n smart-intersection -o jsonpath='{.data.supass}' | base64 -d && echo
    ```

### Access the Grafana UI using Node Port

- Get the Node Port Number using following command and use it to access the Grafana UI

```bash
kubectl get service smart-intersection-grafana -n smart-intersection -o jsonpath='{.spec.ports[0].nodePort}'
```

- Go to http://<HOST_IP>:<Node_PORT>
- **Log in with credentials**:
  - **Username**: `admin`
  - **Password**: `admin`

### Access the InfluxDB UI using Node Port

- Get the Node Port Number using following command and use it to access the InfluxDB UI

```bash
kubectl get service influxdb2 -n smart-intersection -o jsonpath='{.spec.ports[0].nodePort}'
```

- Go to http://<HOST_IP>:<Node_PORT>
- **Log in with credentials**:
  - **Username**: `admin`
  - **Password**: Stored in InfluxDB secrets. To retrieve run the following command:

    ```bash
    kubectl get secret smart-intersection-influxdb-secrets -n smart-intersection -o jsonpath='{.data.influxdb2-admin-password}' | base64 -d && echo
    ```

### Access the NodeRED UI using Node Port

- Get the Node Port Number using following command and use it to access the NodeRED UI

```bash
kubectl get service smart-intersection-nodered -n smart-intersection -o jsonpath='{.spec.ports[0].nodePort}'
```

- Go to http://<HOST_IP>:<Node_PORT>
- **No login required** - NodeRED flows editor for visual programming

### Access the DL Streamer Pipeline Server using Node Port

- Get the Node Port Number using following commands:

```bash
kubectl get service smart-intersection-dlstreamer-pipeline-server -n smart-intersection -o jsonpath='{.spec.ports[0].nodePort}'
```

- **API Access**: http://<HOST_IP>:<API_PORT>/pipelines/status
- **Purpose**: AI pipeline management and streaming interface

## Uninstall the Application

To uninstall the application, run the following command:

```bash
helm uninstall smart-intersection -n smart-intersection
```

## Delete the Namespace

To delete the namespace and all resources within it, run the following command:

```bash
kubectl delete namespace smart-intersection
```

## Complete Cleanup (Optional)

If you want to completely remove all infrastructure components installed during the setup process, including cert-manager and storage provisioner:

### Remove cert-manager
```bash
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
```

### Remove local-path-provisioner (if installed)
```bash
kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

### Remove additional storage classes (if created)
```bash
kubectl delete storageclass hostpath local-storage standard
```

> **Note**: This complete cleanup will remove all certificate management capabilities and storage provisioning from your cluster. You'll need to reinstall these components for future deployments.

## What to Do Next

- **[Troubleshooting Helm Deployments](./support.md#troubleshooting-helm-deployments)**: Consolidated troubleshooting steps for resolving issues during Helm deployments.
- **[Get Started](./get-started.md)**: Ensure you have completed the initial setup steps before proceeding.

## Supporting Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Helm Documentation](https://helm.sh/docs/)
