#!/bin/bash
set -e

### Load environment variables
if [ -f .env ]; then
  echo "Loading environment variables from .env..."
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found - please create one in the project root."
  exit 1
fi

### Terraform provisioning
echo "Running Terraform..."
cd terraform
terraform init
terraform apply -auto-approve
cd ..

### Read Terraform outputs
echo "Reading Terraform outputs..."
ACR_LOGIN_SERVER=$(terraform -chdir=terraform output -raw acr_login_server)
RESOURCE_GROUP=$(terraform -chdir=terraform output -raw resource_group_name)
AKS_NAME=$(terraform -chdir=terraform output -raw aks_name)
COSMOS_ENDPOINT=$(terraform -chdir=terraform output -raw cosmos_endpoint)
COSMOS_KEY=$(terraform -chdir=terraform output -raw cosmos_key)

### Build and push Docker image
echo "Building Docker image: $IMAGE_NAME"
docker build -f webserver/Dockerfile -t $ACR_LOGIN_SERVER/$IMAGE_NAME:latest .

echo "Logging in to ACR..."
az acr login --name $(echo $ACR_LOGIN_SERVER | cut -d. -f1)

echo "Pushing Docker image to ACR..."
docker push $ACR_LOGIN_SERVER/$IMAGE_NAME:latest

### Configure AKS access
echo "Getting AKS credentials..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --overwrite-existing

### Install helm if not available
if ! command -v helm &> /dev/null
then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "Helm is already installed."
fi

CHART_PATH=${HELM_CHART_PATH:-./helm/flask-web}

### Check Helm Chart
if [ ! -f "$CHART_PATH/Chart.yaml" ]; then
  echo "Helm chart not found at $CHART_PATH – creating a new one..."
  mkdir -p "$(dirname "$CHART_PATH")"
  helm create "$CHART_PATH"
  
  # Optional: Clean up unnecessary example files
  rm -f "$CHART_PATH/templates/tests/*"
  echo "Helm chart created."
else
  echo "Helm chart found at $CHART_PATH"
fi

### Helm deployment
echo "Deploying with Helm..."
helm upgrade --install $HELM_RELEASE_NAME $HELM_CHART_PATH \
  --set image.repository=$ACR_LOGIN_SERVER/$IMAGE_NAME \
  --set image.tag=latest \
  --set env.COSMOS_ENDPOINT=$COSMOS_ENDPOINT \
  --set env.COSMOS_KEY=$COSMOS_KEY \
  --set env.COSMOS_DB=webdb \
  --set env.COSMOS_CONTAINER=webdata

echo "Deployment complete"
echo "Getting deployed pod and container port..."

# Get pod name
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=${HELM_RELEASE_NAME},app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath="{.items[0].metadata.name}")

# Get container port
export CONTAINER_PORT=$(kubectl get pod --namespace default "$POD_NAME" -o jsonpath="{.spec.containers[0].ports[0].containerPort}")

echo ""
echo "Flask app deployed!"
echo "Access it locally via port-forward:"
echo ""
echo "  Pod: $POD_NAME"
echo "  Container port: $CONTAINER_PORT"
echo ""
echo "  ▶ Run this to access it in your browser:"
echo "     http://127.0.0.1:8080"
echo ""
echo "Starting port-forward now..."
echo ""

echo "Waiting for pod to be in 'Running' state..."

# Wait 60 seconds for "Running"
for i in {1..30}; do
  STATUS=$(kubectl get pod "$POD_NAME" -o jsonpath="{.status.phase}")
  if [ "$STATUS" == "Running" ]; then
    echo "Pod is running!"
    break
  fi
  echo "  Status: $STATUS – retrying in 2s..."
  sleep 2
done

if [ "$STATUS" != "Running" ]; then
  echo "Pod did not reach 'Running' state. Current status: $STATUS"
  exit 1
fi

# Start port-foward
kubectl --namespace default port-forward "$POD_NAME" 8080:"$CONTAINER_PORT"

