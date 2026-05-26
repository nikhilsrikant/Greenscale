param(
    [Parameter(Mandatory=$true)]
    [string]$RegistryNamespace,

    [string]$Tag = "v1",

    [switch]$NoPush
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found. Install it and open a new PowerShell window."
    }
}

function Normalize-Prefix {
    param([string]$Prefix)
    $value = $Prefix.Trim()
    while ($value.EndsWith("/")) {
        $value = $value.Substring(0, $value.Length - 1)
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "RegistryNamespace cannot be empty. Example: yourdockerhubname or 123456789012.dkr.ecr.us-east-1.amazonaws.com"
    }
    return $value
}

Require-Command docker

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

$prefix = Normalize-Prefix $RegistryNamespace
$orchestratorImage = "$prefix/greenscale-orchestrator:$Tag"
$workerImage = "$prefix/greenscale-worker:$Tag"

Write-Host "Building GreenScale images..." -ForegroundColor Cyan
Write-Host "  Orchestrator: $orchestratorImage"
Write-Host "  Worker:       $workerImage"

docker build -t $orchestratorImage .\orchestrator
docker build -t $workerImage .\worker

if ($NoPush) {
    Write-Host "NoPush was provided, so images were built locally but not pushed." -ForegroundColor Yellow
}
else {
    Write-Host "Pushing images to registry..." -ForegroundColor Cyan
    docker push $orchestratorImage
    docker push $workerImage
}

Write-Host "Image workflow complete." -ForegroundColor Green
Write-Host "Use this image prefix for cloud manifests: $prefix"
Write-Host "Use this tag: $Tag"
