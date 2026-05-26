<#
Milestone 4: Deploy GreenScale to local Kubernetes with kind.

Requires:
- Docker Desktop running
- kubectl
- kind

This script builds local images, loads them into kind, applies Kubernetes manifests,
and waits for the core application plus Prometheus/Grafana to become available.
#>

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ClusterName = $env:CLUSTER_NAME
if ([string]::IsNullOrWhiteSpace($ClusterName)) {
    $ClusterName = "greenscale"
}

function Require-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found. Install it, close PowerShell, reopen PowerShell, and try again."
    }
}

function Apply-ConfigMapFromFile {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "ConfigMap source file not found: $Path"
    }

    kubectl -n greenscale create configmap $Name --from-file="$Key=$Path" --dry-run=client -o yaml | kubectl apply -f -
}

Write-Host "Checking required tools..." -ForegroundColor Cyan
Require-Command docker
Require-Command kubectl
Require-Command kind

Write-Host "Checking Docker engine..." -ForegroundColor Cyan
docker info *> $null

Write-Host "Stopping Docker Compose stack if it is running, to avoid port conflicts later..." -ForegroundColor Cyan
if (Test-Path ".\docker-compose.yml") {
    docker compose down 2>$null
}

Write-Host "Creating kind cluster '$ClusterName' if needed..." -ForegroundColor Cyan
$clusters = kind get clusters 2>$null
if ($LASTEXITCODE -ne 0) {
    $clusters = @()
}
if ($clusters -notcontains $ClusterName) {
    kind create cluster --name $ClusterName --config .\k8s\kind-config.yaml
} else {
    Write-Host "  Cluster already exists."
}

Write-Host "Building local Docker images..." -ForegroundColor Cyan
docker build -t greenscale-orchestrator:dev .\orchestrator
docker build -t greenscale-worker:dev .\worker

Write-Host "Loading images into kind..." -ForegroundColor Cyan
kind load docker-image greenscale-orchestrator:dev --name $ClusterName
kind load docker-image greenscale-worker:dev --name $ClusterName

Write-Host "Applying namespace..." -ForegroundColor Cyan
kubectl apply -f .\k8s\namespace.yaml

Write-Host "Creating observability ConfigMaps..." -ForegroundColor Cyan
Apply-ConfigMapFromFile -Name "prometheus-config" -Key "prometheus.yml" -Path ".\observability\prometheus\prometheus-k8s.yml"
Apply-ConfigMapFromFile -Name "grafana-datasources" -Key "prometheus.yml" -Path ".\observability\grafana\provisioning\datasources\prometheus.yml"
Apply-ConfigMapFromFile -Name "grafana-dashboard-providers" -Key "dashboards.yml" -Path ".\observability\grafana\provisioning\dashboards\dashboards.yml"
Apply-ConfigMapFromFile -Name "grafana-dashboard" -Key "greenscale-dashboard.json" -Path ".\observability\grafana\dashboards\greenscale-dashboard.json"

Write-Host "Applying GreenScale Kubernetes manifests..." -ForegroundColor Cyan
kubectl apply -f .\k8s\configmap.yaml
kubectl apply -f .\k8s\workers.yaml
kubectl apply -f .\k8s\orchestrator.yaml
kubectl apply -f .\k8s\hpa.yaml
kubectl apply -f .\k8s\observability.yaml

Write-Host "Waiting for rollouts..." -ForegroundColor Cyan
kubectl -n greenscale rollout status deploy/aws-worker --timeout=180s
kubectl -n greenscale rollout status deploy/azure-worker --timeout=180s
kubectl -n greenscale rollout status deploy/gcp-worker --timeout=180s
kubectl -n greenscale rollout status deploy/greenscale-orchestrator --timeout=180s
kubectl -n greenscale rollout status deploy/prometheus --timeout=180s
kubectl -n greenscale rollout status deploy/grafana --timeout=180s

Write-Host "Kubernetes resources:" -ForegroundColor Cyan
kubectl -n greenscale get pods,svc,hpa

Write-Host "" 
Write-Host "Milestone 4 deployment is ready." -ForegroundColor Green
Write-Host "Next, expose the services with:" -ForegroundColor Green
Write-Host "  .\scripts\windows_k8s_port_forward.ps1" -ForegroundColor Yellow
Write-Host "Then run:" -ForegroundColor Green
Write-Host "  .\scripts\windows_k8s_smoke_test.ps1" -ForegroundColor Yellow
