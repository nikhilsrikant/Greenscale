param(
    [int]$Iterations = 10,
    [int]$Concurrency = 2,
    [int]$LocalPort = 18080
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$BaseUrl = "http://localhost:$LocalPort"

$baselines = @(
    @{ Name="weighted_default"; Policy="weighted"; Latency="0.45"; Cost="0.20"; Carbon="0.25"; Cold="0.10" },
    @{ Name="latency_only"; Policy="weighted"; Latency="1.00"; Cost="0.00"; Carbon="0.00"; Cold="0.00" },
    @{ Name="carbon_only"; Policy="weighted"; Latency="0.00"; Cost="0.00"; Carbon="1.00"; Cold="0.00" },
    @{ Name="cost_only"; Policy="weighted"; Latency="0.00"; Cost="1.00"; Carbon="0.00"; Cold="0.00" },
    @{ Name="pareto"; Policy="pareto"; Latency="0.45"; Cost="0.20"; Carbon="0.25"; Cold="0.10" },
    @{ Name="rl"; Policy="rl"; Latency="0.45"; Cost="0.20"; Carbon="0.25"; Cold="0.10" }
)

if (-not (Test-Path ".\.venv\Scripts\python.exe")) {
    python -m venv .venv
}

.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r .\experiments\requirements.txt

$root = "results\baselines_$(Get-Date -Format yyyyMMddTHHmmssZ)"
New-Item -ItemType Directory -Force -Path $root | Out-Null

foreach ($baseline in $baselines) {
    Write-Host "Running baseline $($baseline.Name)..." -ForegroundColor Cyan

    $patchFile = Join-Path $env:TEMP "greenscale-configmap-patch.yaml"

@"
data:
  SCHEDULER_POLICY: "$($baseline.Policy)"
  SCHEDULER_ALPHA_LATENCY: "$($baseline.Latency)"
  SCHEDULER_BETA_COST: "$($baseline.Cost)"
  SCHEDULER_GAMMA_CARBON: "$($baseline.Carbon)"
  SCHEDULER_DELTA_COLDSTART: "$($baseline.Cold)"
"@ | Set-Content $patchFile

    kubectl -n greenscale patch configmap greenscale-config --type=merge --patch-file $patchFile
    kubectl -n greenscale rollout restart deployment/greenscale-orchestrator
    kubectl -n greenscale rollout status deployment/greenscale-orchestrator --timeout=180s

    Write-Host "Starting temporary port-forward on $BaseUrl ..." -ForegroundColor Yellow
    $pf = Start-Process -FilePath "kubectl" `
        -ArgumentList @("-n","greenscale","port-forward","svc/greenscale-orchestrator","$($LocalPort):8080") `
        -PassThru `
        -WindowStyle Hidden

    try {
        $ready = $false
        for ($i = 0; $i -lt 30; $i++) {
            try {
                Invoke-RestMethod -Uri "$BaseUrl/health" -Method Get -TimeoutSec 3 | Out-Null
                $ready = $true
                break
            }
            catch {
                Start-Sleep -Seconds 2
            }
        }

        if (-not $ready) {
            throw "Could not reach GreenScale orchestrator at $BaseUrl after rollout."
        }

        $outDir = Join-Path $root $baseline.Name

        .\.venv\Scripts\python.exe .\experiments\run_experiments.py `
            --base-url $BaseUrl `
            --iterations $Iterations `
            --concurrency $Concurrency `
            --out-dir $outDir `
            --analyze
    }
    finally {
        if ($pf -and -not $pf.HasExited) {
            Stop-Process -Id $pf.Id -Force
        }
    }
}

Write-Host "Baseline comparison complete: $root" -ForegroundColor Green
