param(
    [Parameter(Mandatory=$true)]
    [string]$RegistryNamespace,

    [string]$Tag = "v1",

    [switch]$UseLoadBalancer
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found. Install it and open a new PowerShell window."
    }
}

Require-Command kubectl

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

$manifest = ".\k8s\rendered\greenscale-cloud.yaml"

Write-Host "Rendering cloud manifests..." -ForegroundColor Cyan
if ($UseLoadBalancer) {
    & .\scripts\windows_render_cloud_manifests.ps1 -RegistryNamespace $RegistryNamespace -Tag $Tag -OutputPath $manifest -UseLoadBalancer
}
else {
    & .\scripts\windows_render_cloud_manifests.ps1 -RegistryNamespace $RegistryNamespace -Tag $Tag -OutputPath $manifest
}

Write-Host "Applying manifests to current Kubernetes context..." -ForegroundColor Cyan
kubectl apply -f $manifest

Write-Host "Waiting for GreenScale rollouts..." -ForegroundColor Cyan
kubectl -n greenscale rollout status deployment/aws-worker --timeout=180s
kubectl -n greenscale rollout status deployment/azure-worker --timeout=180s
kubectl -n greenscale rollout status deployment/gcp-worker --timeout=180s
kubectl -n greenscale rollout status deployment/greenscale-orchestrator --timeout=180s
kubectl -n greenscale rollout status deployment/prometheus --timeout=180s
kubectl -n greenscale rollout status deployment/grafana --timeout=180s

Write-Host "Cloud deployment completed for context:" -ForegroundColor Green
kubectl config current-context

Write-Host "Current resources:" -ForegroundColor Cyan
kubectl -n greenscale get pods,svc,hpa

if ($UseLoadBalancer) {
    Write-Host "If your cloud provider supports LoadBalancer Services, wait for EXTERNAL-IP:" -ForegroundColor Yellow
    Write-Host "  kubectl -n greenscale get svc greenscale-orchestrator -w"
}
else {
    Write-Host "Use port forwarding to access the app:" -ForegroundColor Yellow
    Write-Host "  .\scripts\windows_k8s_port_forward.ps1"
}
