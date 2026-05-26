<#
Deploy GreenScale to local Kubernetes with kind on Windows.
Requires Docker Desktop, kubectl, and kind.
#>

$ErrorActionPreference = "Stop"

$clusterName = "greenscale"

Write-Host "Creating kind cluster if needed..." -ForegroundColor Cyan
$clusters = kind get clusters 2>$null
if ($clusters -notcontains $clusterName) {
    kind create cluster --name $clusterName
}

Write-Host "Building Docker images..." -ForegroundColor Cyan
docker build -t greenscale-orchestrator:dev .\orchestrator
docker build -t greenscale-worker:dev .\worker

Write-Host "Loading images into kind..." -ForegroundColor Cyan
kind load docker-image greenscale-orchestrator:dev --name $clusterName
kind load docker-image greenscale-worker:dev --name $clusterName

Write-Host "Applying Kubernetes manifests..." -ForegroundColor Cyan
kubectl apply -f .\k8s\

Write-Host "Waiting for rollout..." -ForegroundColor Cyan
kubectl -n greenscale rollout status deploy/greenscale-orchestrator
kubectl -n greenscale rollout status deploy/aws-worker
kubectl -n greenscale rollout status deploy/azure-worker
kubectl -n greenscale rollout status deploy/gcp-worker

Write-Host "\nRun this in the same PowerShell window to expose the API:" -ForegroundColor Green
Write-Host "kubectl -n greenscale port-forward svc/greenscale-orchestrator 8080:8080"
