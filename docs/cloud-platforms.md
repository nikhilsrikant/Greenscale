# Deploying GreenScale on AWS, Azure, and Google Cloud

GreenScale is designed around plain Kubernetes manifests. That means the same core application can run on managed Kubernetes services with minimal changes.

## AWS EKS path

High-level flow:

```bash
# Install/configure awscli and eksctl first.
eksctl create cluster \
  --name greenscale \
  --region us-east-1 \
  --nodes 3 \
  --node-type t3.medium

aws ecr create-repository --repository-name greenscale-orchestrator
aws ecr create-repository --repository-name greenscale-worker

# Build and push images to ECR, then update k8s image names.
kubectl apply -f k8s/
```

## Azure AKS path

```bash
az group create --name greenscale-rg --location westus
az aks create \
  --resource-group greenscale-rg \
  --name greenscale \
  --node-count 3 \
  --node-vm-size Standard_B2s \
  --generate-ssh-keys
az aks get-credentials --resource-group greenscale-rg --name greenscale

# Push images to Azure Container Registry, update k8s image names, then:
kubectl apply -f k8s/
```

## Google GKE path

```bash
gcloud container clusters create greenscale \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type e2-medium

gcloud container clusters get-credentials greenscale --zone us-central1-a

# Push images to Artifact Registry, update k8s image names, then:
kubectl apply -f k8s/
```

## Moving from simulated to real multi-region

The current MVP simulates regions as separate worker deployments. For real multi-region experiments, use one of these designs:

1. One cluster per region, one orchestrator with a global registry.
2. One orchestrator per region plus global load balancer.
3. Multi-cluster service mesh such as Istio/Linkerd service mirroring.
4. Serverless layer using Knative Serving or OpenFaaS per cluster.

## What to change for real experiments

- Replace the service URLs in `REGION_ENDPOINTS` with actual regional ingress URLs.
- Replace static `carbon_gco2_kwh` with real-time or historical carbon traces.
- Feed measured latency into the scheduler instead of configured `base_latency_ms`.
- Add storage/data residency constraints if your workload handles sensitive data.
