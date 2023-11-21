# Free Tier AKS

Purpose of this cluster was to build an AKS cluster for the express purpose of using it to setup a Cilium ClusterMesh with my [Free Tier GKE](https://github.com/Neutrollized/free-tier-gke) cluster.

## Why AKS?
I chose AKS because like Google, Azure also has a [free tier](https://learn.microsoft.com/en-us/azure/aks/free-standard-pricing-tiers) offering for their managed Kubernetes service that is pretty decent.


## Installing Cilium
One of the Terraform outputs will include the command to install Cilium and it will look something similar to the one shown below.  The `cluster.id` needs to be unique across clusters in your cluster mesh and hence I've based the Resource Group name on the variables, `aks_cluster_name_prefix` and `cluster_id` to help ensure uniqueness.

- example:
```console
cilium install \
  --version 1.14.3 \
  --set cluster.name="playground-aks-6" \
  --set cluster.id=6 \
  --set azure.resourceGroup="playground-aks-6-rg" \
  --set ipam.operator.clusterPoolIPv4PodCIDRList='{10.100.0.0/18}'
```

- example output:
```
🔮 Auto-detected Kubernetes kind: AKS
ℹ️  Using Cilium version 1.14.3
ℹ️  Using cluster name "playground-aks-6"
✅ Derived Azure subscription ID 12345678-90ab-cdef-edcb-a09876543210 from subscription MySubscription
✅ Detected Azure AKS cluster in BYOCNI mode (no CNI plugin pre-installed)
🔮 Auto-detected kube-proxy has been installed
```

## ClusterMesh setup
Documentation and examples can be found [here](./cilium/clustermesh/)

