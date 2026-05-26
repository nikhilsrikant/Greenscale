# Milestone 4: Kubernetes Deployment with kind

Milestone 4 moves GreenScale from Docker Compose into Kubernetes. This is the bridge between the local prototype and managed cloud Kubernetes platforms such as AWS EKS, Azure AKS, and Google GKE.

## What this milestone deploys

The Kubernetes deployment includes:

- `greenscale-orchestrator` Deployment and Service
- `aws-worker`, `azure-worker`, and `gcp-worker` Deployments and Services
- Kubernetes ConfigMap for scheduler weights and region endpoint definitions
- HorizontalPodAutoscaler objects for the orchestrator and workers
- Prometheus Deployment and Service
- Grafana Deployment and Service
- Grafana dashboard and datasource provisioning through ConfigMaps

## Prerequisites on Windows

Docker Desktop must be running before using kind.

Install Kubernetes tools from PowerShell:

```powershell
winget install -e --id Kubernetes.kubectl
winget install -e --id Kubernetes.kind
```

Close and reopen PowerShell, then verify:

```powershell
kubectl version --client
kind version
docker info
```

## Deploy GreenScale to Kubernetes

From the project root:

```powershell
cd C:\Users\kulka\downloads\greenscale
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows_run_milestone4.ps1
```

The script will:

1. Stop the Docker Compose stack if it is running.
2. Create a local kind cluster named `greenscale` if needed.
3. Build the orchestrator and worker images.
4. Load those images into the kind cluster.
5. Create observability ConfigMaps for Prometheus and Grafana.
6. Apply the Kubernetes manifests.
7. Wait for all Deployments to roll out.

## Expose local ports

Run:

```powershell
.\scripts\windows_k8s_port_forward.ps1
```

This opens local access to:

| Service | URL |
|---|---|
| Orchestrator | http://localhost:8080/health |
| Prometheus | http://localhost:9090/targets |
| Grafana | http://localhost:3000 |

Grafana login:

```text
username: admin
password: greenscale
```

## Smoke test

After the port-forward windows are running:

```powershell
.\scripts\windows_k8s_smoke_test.ps1
```

Expected ending:

```text
Milestone 4 Kubernetes smoke test passed.
```

## Check Kubernetes status

```powershell
.\scripts\windows_k8s_status.ps1
```

Useful manual commands:

```powershell
kubectl -n greenscale get pods
kubectl -n greenscale get svc
kubectl -n greenscale get hpa
kubectl -n greenscale logs deploy/greenscale-orchestrator
```

## Run experiments against Kubernetes

Once `windows_k8s_port_forward.ps1` is running, the same experiment automation from Milestone 2 works because the orchestrator is exposed at `http://localhost:8080`:

```powershell
.\scripts\windows_run_experiments.ps1
```

## How this maps to AWS, Azure, and Google Cloud

The local kind deployment uses the same Kubernetes API objects that managed cloud Kubernetes platforms use. For real cloud deployment, the main changes are:

1. Build images.
2. Push images to a cloud container registry.
3. Replace `greenscale-orchestrator:dev` and `greenscale-worker:dev` in the Kubernetes manifests with registry image URLs.
4. Apply the manifests to EKS, AKS, or GKE instead of kind.
5. Replace local port-forwarding with a cloud LoadBalancer or Ingress.

This is why Milestone 4 is the correct step before cloud deployment.

## Clean up

Delete only the GreenScale namespace:

```powershell
kubectl delete namespace greenscale
```

Delete the entire local kind cluster:

```powershell
kind delete cluster --name greenscale
```
