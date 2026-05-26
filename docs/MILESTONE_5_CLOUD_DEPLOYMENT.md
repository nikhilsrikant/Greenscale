# Milestone 5: Registry and cloud deployment workflow

Milestone 5 makes GreenScale portable beyond local Docker and Kind.

The goal is to move from local-only images:

```text
greenscale-orchestrator:dev
greenscale-worker:dev
```

to registry images that any Kubernetes cluster can pull:

```text
your-registry-prefix/greenscale-orchestrator:v1
your-registry-prefix/greenscale-worker:v1
```

## 1. Recommended first path: Docker Hub

Docker Hub is the easiest first registry because the image prefix is simply your Docker Hub username.

From the GreenScale project root:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows_dockerhub_quickstart.ps1 -DockerHubUsername YOUR_DOCKERHUB_USERNAME -Tag v1
```

This does three things:

1. Runs `docker login`.
2. Builds and pushes both GreenScale images.
3. Renders a cloud-ready Kubernetes manifest.

The generated manifest will be:

```text
k8s\rendered\greenscale-cloud.yaml
```

Deploy it to whichever Kubernetes context is active:

```powershell
kubectl apply -f .\k8s\rendered\greenscale-cloud.yaml
kubectl -n greenscale get pods,svc,hpa
```

## 2. Generic registry workflow

Use this if you are using AWS ECR, Azure Container Registry, Google Artifact Registry, GitHub Container Registry, or another registry.

```powershell
.\scripts\windows_build_push_registry.ps1 -RegistryNamespace REGISTRY_PREFIX -Tag v1
.\scripts\windows_render_cloud_manifests.ps1 -RegistryNamespace REGISTRY_PREFIX -Tag v1
kubectl apply -f .\k8s\rendered\greenscale-cloud.yaml
```

Examples of `REGISTRY_PREFIX`:

```text
Docker Hub:              yourdockerhubname
AWS ECR:                 123456789012.dkr.ecr.us-east-1.amazonaws.com
Azure Container Registry: myregistry.azurecr.io
Google Artifact Registry: us-central1-docker.pkg.dev/my-project/greenscale
```

## 3. Deploy to a managed Kubernetes cluster

After your cluster exists and `kubectl` points to it, run:

```powershell
.\scripts\windows_cloud_deploy.ps1 -RegistryNamespace REGISTRY_PREFIX -Tag v1
```

Then expose locally:

```powershell
kubectl -n greenscale port-forward svc/greenscale-orchestrator 8080:8080
kubectl -n greenscale port-forward svc/prometheus 9090:9090
kubectl -n greenscale port-forward svc/grafana 3000:3000
```

Smoke test:

```powershell
.\scripts\windows_cloud_smoke_test.ps1
```

## 4. Optional public endpoint for demos

For a short demo, you can render the orchestrator service as a cloud LoadBalancer:

```powershell
.\scripts\windows_cloud_deploy.ps1 -RegistryNamespace REGISTRY_PREFIX -Tag v1 -UseLoadBalancer
kubectl -n greenscale get svc greenscale-orchestrator -w
```

A LoadBalancer can create billable cloud resources. Delete the deployment when finished.

## 5. AWS EKS notes

A normal AWS path is:

1. Create ECR repositories for `greenscale-orchestrator` and `greenscale-worker`.
2. Authenticate Docker to ECR.
3. Build and push images using the ECR registry prefix.
4. Create or select an EKS cluster.
5. Apply the rendered manifest.

Example registry prefix:

```text
123456789012.dkr.ecr.us-east-1.amazonaws.com
```

Example GreenScale commands:

```powershell
.\scripts\windows_build_push_registry.ps1 -RegistryNamespace 123456789012.dkr.ecr.us-east-1.amazonaws.com -Tag v1
.\scripts\windows_cloud_deploy.ps1 -RegistryNamespace 123456789012.dkr.ecr.us-east-1.amazonaws.com -Tag v1
```

## 6. Azure AKS notes

A normal Azure path is:

1. Create an Azure Container Registry.
2. Build and push GreenScale images to the ACR login server.
3. Create or select an AKS cluster with access to the registry.
4. Apply the rendered manifest.

Example registry prefix:

```text
myregistry.azurecr.io
```

Example GreenScale commands:

```powershell
.\scripts\windows_build_push_registry.ps1 -RegistryNamespace myregistry.azurecr.io -Tag v1
.\scripts\windows_cloud_deploy.ps1 -RegistryNamespace myregistry.azurecr.io -Tag v1
```

## 7. Google GKE notes

A normal Google Cloud path is:

1. Create an Artifact Registry Docker repository.
2. Configure Docker authentication for that repository.
3. Build and push GreenScale images to the Artifact Registry path.
4. Create or select a GKE cluster that can pull from the repository.
5. Apply the rendered manifest.

Example registry prefix:

```text
us-central1-docker.pkg.dev/my-project/greenscale
```

Example GreenScale commands:

```powershell
.\scripts\windows_build_push_registry.ps1 -RegistryNamespace us-central1-docker.pkg.dev/my-project/greenscale -Tag v1
.\scripts\windows_cloud_deploy.ps1 -RegistryNamespace us-central1-docker.pkg.dev/my-project/greenscale -Tag v1
```

## 8. Validate the deployment

```powershell
kubectl -n greenscale get pods,svc,hpa
kubectl -n greenscale logs deployment/greenscale-orchestrator --tail=50
.\scripts\windows_cloud_smoke_test.ps1
```

For Grafana:

```text
http://localhost:3000
admin / greenscale
```

## 9. Tear down

Local Kind:

```powershell
kind delete cluster --name greenscale
```

Any Kubernetes cluster:

```powershell
kubectl delete namespace greenscale
```

Managed cloud clusters should also be deleted when you are finished to avoid ongoing charges.
