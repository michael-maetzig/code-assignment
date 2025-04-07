# Interview Coding Assignment

This project hosts a webserver in the cloud that can handle POST and GET requests. The project uses **Terraform** to provision infrastructure in **Azure**, deploys a containerized **Flask web application** via **Helm** on **Azure Kubernetes Service (AKS)**, and integrates it with **Azure Cosmos DB**.

The application exposes a HTTP endpoint to:
- `POST /data`: Store JSON data in Cosmos DB
- `GET /data`: Retrieve data from Cosmos DB
- `GET /datalocal`: Retrieve local data from the application

The URL to reach the application is returned as part of the deployment (see Deployment).

---

## Tech Stack

| Component      | Technology                |
|----------------|----------------------------|
| Infrastructure | Terraform                  |
| Cloud Provider | Azure                      |
| Container      | Docker                     |
| Orchestration  | Azure Kubernetes Service   |
| Deployment     | Helm                       |
| Backend        | Python (Flask)             |
| Database       | Azure Cosmos DB (SQL API)  |

---

## Project Structure
. 
├── terraform/ # Terraform for AKS & Cosmos DB 
├── webserver/ # Flask app & Dockerfile 
├── helm/flask-web/ # Helm chart for deployment 
└── README.md

## Prerequisites

- Azure account & [Azure CLI] for local commands (https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- Azure Blob Storage configured to enable a remote backend for Terraform
- GitHub account (to execute Workflows)

You need to setup the following CI/CD variables in GitHub
| Variable               | Purpose                          |
|------------------------|----------------------------------|
| `AZURE_CLIENT_ID`      | Azure service principal ID       |
| `AZURE_CLIENT_SECRET`  | Azure service principal secret   |
| `AZURE_SUBSCRIPTION_ID`| Azure subscription ID            |
| `AZURE_TENANT_ID`      | Azure tenant ID                  |
| `AZURE_CREDENTIALS`    | The above credentials in a JSON  |

### Azure Credentials JSON
The credentials JSON should look like:

{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}

### Terraform Remote Backend
Please set the remote backend configuration for Azure in the terraform/backend.tf before running the workflows.

---

## Deployment

The workflow "Deploy" needs to be triggered manually via GitHub Actions.

1. Terraform-And-Docker: initializes Terraform setup and applies changes; creates the Docker images and pushes it to Azure Container Registry
2. Helm-Run: configures Helm and runs the app on Azure Kubernetes Service

In the Helm-Run job, the step "Waiting for LoadBalancer IP" outputs the URL the app is running on.

## Clean-up
The workflow "Destroy" needs to be triggered manually via GitHub Actions.

1. Terraform-Destroy: cleans-up the Terraform resources
2. Helm-Uninstall: uninstalls the Helm release

---

## Troubleshooting

Some initial errors might occur due to missing permissions for specific roles or Azure services to reach other services.

---

## Example Requests

### POST
#### Bash
curl.exe -X POST http://URL/data -H "Content-Type: application/json" -d "{\"id\": \"6\", \"categoryName\": \"formula-1-team\", \"name\": \"Williams\", \"driver1\": \"Carlos Sainz\", \"driver2\": \"Alexander Albon\"}"
#### Windows PowerShell
Invoke-RestMethod -Uri "http://132.164.1.130:80/data" -Method Post -ContentType "application/json" -Body '{"id": "20", "categoryName": "formula-1-team", "name": "Racing Bulls", "driver1": "Yuki Tsunoda", "driver2": "Isack Hadjar"}'

### GET
http://URL/data
http://URL/datalocal
