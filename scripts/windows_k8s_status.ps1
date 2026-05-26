$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "GreenScale Kubernetes status" -ForegroundColor Cyan
kubectl -n greenscale get pods -o wide
kubectl -n greenscale get svc
kubectl -n greenscale get hpa
Write-Host "" 
Write-Host "Recent events" -ForegroundColor Cyan
kubectl -n greenscale get events --sort-by=.lastTimestamp | Select-Object -Last 20
