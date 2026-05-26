# Cloud command cheatsheet for GreenScale

This file gives copy-paste command patterns. Replace uppercase placeholders before running.

## Docker Hub

```powershell
docker login
.\scripts\windows_build_push_registry.ps1 -RegistryNamespace YOUR_DOCKERHUB_USERNAME -Tag v1
.\scripts\windows_render_cloud_manifests.ps1 -RegistryNamespace YOUR_DOCKERHUB_USERNAME -Tag v1
kubectl apply -f .\k8s\rendered\greenscale-cloud.yaml
```

## AWS ECR pattern

```powershell
$REGION="us-east-1"
$ACCOUNT_ID="123456789012"
$PREFIX="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

aws ecr create-repository --repository-name greenscale-orchestrator --region $REGION
aws ecr create-repository --repository-name greenscale-worker --region $REGION
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $PREFIX

.\scripts\windows_build_push_registry.ps1 -RegistryNamespace $PREFIX -Tag v1
.\scripts\windows_cloud_deploy.ps1 -RegistryNamespace $PREFIX -Tag v1
```

## Azure ACR pattern

```powershell
$ACR_NAME="YOUR_UNIQUE_ACR_NAME"
$PREFIX="$ACR_NAME.azurecr.io"

az acr login --name $ACR_NAME
.\scripts\windows_build_push_registry.ps1 -RegistryNamespace $PREFIX -Tag v1
.\scripts\windows_cloud_deploy.ps1 -RegistryNamespace $PREFIX -Tag v1
```

## Google Artifact Registry pattern

```powershell
$PROJECT_ID="YOUR_PROJECT_ID"
$LOCATION="us-central1"
$REPOSITORY="greenscale"
$PREFIX="$LOCATION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY"

gcloud auth configure-docker "$LOCATION-docker.pkg.dev"
.\scripts\windows_build_push_registry.ps1 -RegistryNamespace $PREFIX -Tag v1
.\scripts\windows_cloud_deploy.ps1 -RegistryNamespace $PREFIX -Tag v1
```

## Smoke test after deployment

```powershell
kubectl -n greenscale port-forward svc/greenscale-orchestrator 8080:8080
.\scripts\windows_cloud_smoke_test.ps1
```
