# Kubernetes manifests

These manifests deploy GreenScale as Kubernetes-native workloads.

## Local kind image names

For local kind development, the manifests use:

- `greenscale-orchestrator:dev`
- `greenscale-worker:dev`

The Milestone 4 scripts build these images locally and load them into kind.

## Windows quick start

```powershell
cd C:\Users\kulka\downloads\greenscale
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows_run_milestone4.ps1
.\scripts\windows_k8s_port_forward.ps1
.\scripts\windows_k8s_smoke_test.ps1
```

## Linux/macOS quick start

```bash
./scripts/run_milestone4.sh
./scripts/k8s_port_forward.sh
./scripts/k8s_smoke_test.sh
```

## Manual deployment flow

```bash
kind create cluster --name greenscale --config k8s/kind-config.yaml

docker build -t greenscale-orchestrator:dev ./orchestrator
docker build -t greenscale-worker:dev ./worker

kind load docker-image greenscale-orchestrator:dev --name greenscale
kind load docker-image greenscale-worker:dev --name greenscale

kubectl apply -f k8s/namespace.yaml
kubectl -n greenscale create configmap prometheus-config --from-file=prometheus.yml=observability/prometheus/prometheus-k8s.yml --dry-run=client -o yaml | kubectl apply -f -
kubectl -n greenscale create configmap grafana-datasources --from-file=prometheus.yml=observability/grafana/provisioning/datasources/prometheus.yml --dry-run=client -o yaml | kubectl apply -f -
kubectl -n greenscale create configmap grafana-dashboard-providers --from-file=dashboards.yml=observability/grafana/provisioning/dashboards/dashboards.yml --dry-run=client -o yaml | kubectl apply -f -
kubectl -n greenscale create configmap grafana-dashboard --from-file=greenscale-dashboard.json=observability/grafana/dashboards/greenscale-dashboard.json --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/workers.yaml
kubectl apply -f k8s/orchestrator.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/observability.yaml
```

## Port forwarding

```bash
kubectl -n greenscale port-forward svc/greenscale-orchestrator 8080:8080
kubectl -n greenscale port-forward svc/prometheus 9090:9090
kubectl -n greenscale port-forward svc/grafana 3000:3000
```

Open:

- Orchestrator: http://localhost:8080/health
- Prometheus: http://localhost:9090/targets
- Grafana: http://localhost:3000

Grafana login: `admin` / `greenscale`.

## Test invocation

```bash
curl -s -X POST http://localhost:8080/invoke/text-classify \
  -H 'Content-Type: application/json' \
  -d '{"payload":{"text":"cloud carbon scheduler"},"slo_ms":500}'
```

## Cloud platform migration

For AWS EKS, Azure AKS, or Google GKE:

1. Push `greenscale-orchestrator` and `greenscale-worker` images to a registry.
2. Replace the local `:dev` image references with your registry URLs.
3. Apply the same manifests to the cloud cluster.
4. Use a LoadBalancer Service or Ingress instead of local port-forwarding.
