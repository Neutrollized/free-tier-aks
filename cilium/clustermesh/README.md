# README

## AKS-to-AKS
Based on [Cilium's documentation](https://docs.cilium.io/en/stable/network/clustermesh/aks-clustermesh-prep/).  The quick and dirty way of getting this up and running is to duplicate this repo under another name and create a second AKS cluster under the same account and peer the two virtual networks (and the VNet IDs are part of the TF outputs, so you don't have to go digging for them).

### VNet peering
I must say that I'm very surprised as to how simple it is to peer two Azure VNets from different resource groups...

- peering VNet 1 with VNet 2
```
az network vnet peering create \
    -g "playground-aks-1-rg" \
    --name "peering-aks1-to-aks2" \
    --vnet-name "playground-aks-1-vnet" \
    --remote-vnet "/subscriptions/12345678-90ab-cdef-edcb-a09876543210/resourceGroups/playground-aks-2-rg/providers/Microsoft.Network/virtualNetworks/playground-aks-2-vnet" \
    --allow-vnet-access
```

- peering VNet 2 with VNet 1
```
az network vnet peering create \
    -g "playground-aks-2-rg" \
    --name "peering-aks2-to-aks1" \
    --vnet-name "playground-aks-2-vnet" \
    --remote-vnet "/subscriptions/12345678-90ab-cdef-edcb-a09876543210/resourceGroups/playground-aks-1-rg/providers/Microsoft.Network/virtualNetworks/playground-aks-1-vnet" \
    --allow-vnet-access
```

### Enable ClusterMesh
```
cilium clustermesh enable --context playground-aks-1 --enable-kvstoremesh
cilium clustermesh enable --context playground-aks-2 --enable-kvstoremesh
```

- (recommended) match Cillium CA certs
```
kubectl --context=playground-aks-2 delete secret -n kube-system cilium-ca

kubectl --context=playground-aks-1 get secret -n kube-system cilium-ca -o yaml | \
  kubectl --context=playground-aks-2 create -f -
```

**NOTE** - if you don't have matching certs, you'll get something like the following when you connect your clusters:
```
...
ℹ️  Found ClusterMesh service IPs: [192.168.64.6]
⚠️ Cilium CA certificates do not match between clusters. Multicluster features will be limited!
ℹ️ Configuring Cilium in cluster 'playground-aks-1' to connect to cluster 'playground-aks-2'
ℹ️ Configuring Cilium in cluster 'playground-aks-2' to connect to cluster 'playground-aks-1'
...
```

### Connect clusters
```
cilium clustermesh connect --context playground-aks-1 --destination-context playground-aks-2
```

### Verify connectivity
```
cilium connectivity test --context playground-aks-1 --multi-cluster playground-aks-2
```

## Demo!
I'm using NGINX ingress controller here, but basically you want to deploy the services in BOTH clusters, but the ingress controller one in one of them.

- installing NGINX ingress controller via Helm:
```console
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx
```

Afterwards, you can it up *http://[LOADBALANCER_IP]/ui* and refresh to watch the services being balanced across both clusters.  You can even delete the web deployment (but NOT the service, as it's the service that's global) on the cluster where the ingress controller is running and everything will still work as it will route to the pods in the other cluster instead.  
