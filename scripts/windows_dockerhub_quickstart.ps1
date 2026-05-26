param(
    [Parameter(Mandatory=$true)]
    [string]$DockerHubUsername,

    [string]$Tag = "v1"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

Write-Host "Logging in to Docker Hub. Use your Docker Hub username and password/access token." -ForegroundColor Cyan
docker login

Write-Host "Building and pushing Docker Hub images..." -ForegroundColor Cyan
& .\scripts\windows_build_push_registry.ps1 -RegistryNamespace $DockerHubUsername -Tag $Tag

Write-Host "Rendering manifests for Docker Hub images..." -ForegroundColor Cyan
& .\scripts\windows_render_cloud_manifests.ps1 -RegistryNamespace $DockerHubUsername -Tag $Tag

Write-Host "Docker Hub quickstart complete." -ForegroundColor Green
Write-Host "Generated manifest: .\k8s\rendered\greenscale-cloud.yaml"
Write-Host "Deploy it to any active Kubernetes cluster with:"
Write-Host "  kubectl apply -f .\k8s\rendered\greenscale-cloud.yaml"
