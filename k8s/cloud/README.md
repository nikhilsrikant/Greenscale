# GreenScale cloud manifests

This folder documents the cloud deployment workflow. The actual cloud manifest is generated into:

```text
k8s/rendered/greenscale-cloud.yaml
```

Generate it with:

```powershell
.\scripts\windows_render_cloud_manifests.ps1 -RegistryNamespace yourdockerhubname -Tag v1
```

The renderer takes the same Kubernetes manifests that work in Kind and replaces local development images with registry-hosted images.

Default rendered images:

```text
yourdockerhubname/greenscale-orchestrator:v1
yourdockerhubname/greenscale-worker:v1
```

For private registries, use the full registry prefix instead of a Docker Hub username.

Examples:

```text
123456789012.dkr.ecr.us-east-1.amazonaws.com
myregistry.azurecr.io
us-central1-docker.pkg.dev/my-project/greenscale
```

By default, the orchestrator Service remains `ClusterIP`, which is safer for experiments. Use port forwarding to access it:

```powershell
kubectl -n greenscale port-forward svc/greenscale-orchestrator 8080:8080
```

For a short-lived demo on a managed cloud Kubernetes cluster, render a LoadBalancer service:

```powershell
.\scripts\windows_render_cloud_manifests.ps1 -RegistryNamespace yourdockerhubname -Tag v1 -UseLoadBalancer
```

A cloud LoadBalancer may create billable infrastructure. Delete it when you are finished.
