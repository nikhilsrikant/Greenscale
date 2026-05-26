# Cloud cost safety checklist

Use this checklist before running GreenScale on AWS, Azure, or Google Cloud.

## Use the smallest sensible cluster

For a short experiment, use a small node count. GreenScale is lightweight and does not need a large cluster for functional validation.

Recommended initial shape:

```text
1 to 2 worker nodes
2 vCPU to 4 vCPU per node
4 GB to 8 GB memory per node
```

## Keep services private by default

The default generated cloud manifest keeps services as `ClusterIP`. Access them with `kubectl port-forward`.

This avoids accidentally creating public cloud load balancers.

## Only use LoadBalancer for short demos

If you render with `-UseLoadBalancer`, your cloud provider may create a billable load balancer.

Delete the namespace after the demo:

```powershell
kubectl delete namespace greenscale
```

## Set budgets and alerts

Before using a managed Kubernetes cluster, configure a billing budget or spending alert in your cloud account.

## Use explicit tags

Do not push only `latest`. Use experiment tags:

```text
v1
v1-eks-demo
v1-aks-demo
v1-gke-demo
```

## Delete clusters after experiments

Deleting the GreenScale namespace removes app resources, but it does not delete the managed Kubernetes cluster itself.

Also delete the cluster from AWS, Azure, or Google Cloud after experiments if it is no longer needed.

## Store experiment outputs locally

Save Milestone 2 outputs before deleting cloud resources:

```text
results\run_*\summary.md
results\run_*\charts\
```
