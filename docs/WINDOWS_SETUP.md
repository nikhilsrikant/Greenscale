# GreenScale Windows setup

This is the recommended Windows path for a clean machine.

## Phase 1: Install only what is needed for the local MVP

Open **PowerShell as Administrator** and run:

```powershell
wsl --install
```

Reboot if Windows asks you to. Then install the project tools:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows_setup.ps1
```

This installs:

- Docker Desktop
- Git
- Python 3.12 for optional unit tests
- Visual Studio Code

Docker Desktop should be configured to use the WSL 2 backend.

## Phase 2: Run GreenScale locally

Open PowerShell in the `greenscale` project folder:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows_run_local.ps1
```

Open a second PowerShell window and run:

```powershell
.\scripts\windows_smoke_test.ps1
```

You can also test manually:

```powershell
Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get | ConvertTo-Json -Depth 10
```

Invoke a workload:

```powershell
$body = @{
    payload = @{ text = "cloud computing research workload" }
    slo_ms = 450
    priority = "latency-critical"
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
    -Uri "http://localhost:8080/invoke/text-classify" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body | ConvertTo-Json -Depth 20
```

## Phase 3: Optional unit tests without Docker

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r .\orchestrator\requirements.txt pytest
pytest -q
```

## Phase 4: Optional local Kubernetes with kind

Install Kubernetes tools:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows_install_k8s_tools.ps1
```

Close and reopen PowerShell, then deploy:

```powershell
.\scripts\windows_kind_deploy.ps1
kubectl -n greenscale port-forward svc/greenscale-orchestrator 8080:8080
```

Then run the smoke test again from another PowerShell window.

## Troubleshooting

### Docker command not found

Close and reopen PowerShell after installing Docker Desktop.

### Docker Engine not running

Open Docker Desktop and wait until the lower-left status says the engine is running.

### Port 8080 already in use

Stop the other service or change the port mapping in `docker-compose.yml`:

```yaml
ports:
  - "8081:8080"
```

Then use `http://localhost:8081`.

### PowerShell blocks scripts

Use this temporary setting in the current PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### Kubernetes pods stay pending

Increase Docker Desktop resources. For kind, allocate at least 6 GB RAM to the Docker VM; 8 GB is better.
