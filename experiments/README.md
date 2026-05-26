# GreenScale experiment automation

This folder implements Milestone 2: repeatable experiment automation, result files, summary statistics, and report-ready charts.

## Prerequisite

Keep the local GreenScale Docker Compose stack running in another terminal:

```powershell
docker compose up --build
```

Verify the orchestrator:

```powershell
Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get | ConvertTo-Json -Depth 10
```

## Windows PowerShell quick start

From the project root:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows_run_milestone2.ps1
```

## Manual Python commands

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r .\experiments\requirements.txt
python .\experiments\run_experiments.py --base-url http://localhost:8080 --out-dir .\results --iterations 10 --concurrency 2 --analyze
```

The run creates a timestamped directory under `results/` containing:

- `raw_responses.jsonl`
- `experiment_results.csv`
- `summary.json`
- `summary.md`
- `charts/*.png`

## Recommended report interpretation

Use `summary.md` as the first draft of your methodology/results section. The CSV can be imported into Excel, R, Python, or Jupyter for additional analysis.
