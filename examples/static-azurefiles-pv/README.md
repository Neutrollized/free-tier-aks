# Persistent Volumes using Statically Provisioned Azure Files

The first question you should be asking yourself is: Why? Why am I using a statically provisioned Azure Files as to provide the volume for PVs when I can use the CSI drivers that's bundled with AKS and dynamically provision my volumes instead?

The answer to this question is that it really depends on the particular org's standards and practices and what they deem as "insecure" (whether you agree or not). 


## Leveraging the Kubelet's identity
If you're mounting a volume from a Storage Account such as Azure Files or Blob, it'll require an account key, which is typically stored as a k8s secret.  There is a way though, to keep your account key out of Kubernetes secret and that is by leveraging the Kubelet's identity and permissions.  You can opt to have Kubelet dynamically fetch your account key for you (and store it in memory...?) 

If you deploy this AKS cluster with `enable_static_azurefiles = true`, it blueprint will deploy a static Storage Account with a Private Endpoint and finally a File Share.

### Using Azure AD / Entra ID groups
As of [v0.13.0](https://github.com/Neutrollized/free-tier-aks/blob/main/CHANGELOG.md#0130---2024-10-21), I've updated the role assignment to an Azure AD group instead of directly to the Kubelet identity.  This makes management easier in scenarios where multiple principals may need access to the same Storage Account. 

### Storage Account deployment note 
I don't know if this a bug or if it's working as intended, but when you go throught the CSI driver to dynamically provision an Azure Files share with a Private Endpoint, it creates a Storage Account network rule that allows no external networks allowing only *AzureServices* to bypass it.  Because your traffic is coming from your CSI driver in your AKS node that is the same network already (remember: Private Endpoint), this traffic is internal/local. 

Also, do not set `public_network_access_enabled = false` as that's just the network rules minus the exception.

Here, deploying with Terraform (whether it's from my laptop or from a CI/CD service), the request is coming from a source that is external to the Storage Account's network and hence when it goes and provisions the Azure Files file share, it will error out citing insufficient permissions.  As a result, you should be providing your own IP in the `storacct_authorized_ip_ranges` (because the default of *0.0.0.0/0* just means it's public), and that's not what you want if you're going to use a Private Endpoint.

### `StorageClass`, `PersistentVolume` and `PersistentVolumeClaim`
You will have to create your own storage class if you wish to use Private Endpoint as well adding some details about the volume in your PV parameters. In the [PV's parameters](https://learn.microsoft.com/en-us/azure/aks/azure-csi-files-storage-provision#static-provisioning-parameters-for-persistentvolume) , be sure to leave out `spec.csi.nodeStageSecretRef.name` so that the Kubelet's identity gets used to obtain account key.

I have provided a custom SC, PV and PVC definition for you to try out.  At the end, you should have a volume that is mounted into your pod using a Private Endpoint and no account key stored as a Kubernetes secret! 

**NOTE**: some of the SC parameters I set are actually only for [dynamically provisioned PVs](https://learn.microsoft.com/en-us/azure/aks/azure-csi-files-storage-provision#storage-class-parameters-for-dynamic-persistentvolumes) and not really recognized, but I specify explicitly to serve more as a documentation

## Using Workload Identity
A requirement to use [Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview?tabs=dotnet) with statically provisioned Azure Files is an AKS cluster that is v1.29+ (I tested on v1.30).  It works very similar to using a the Kubelet's identity option, but you have to provide `spec.csi.volumeAttributes.clientID` as well (which is the client ID of your Workload Identity federated user) in the PV's parameters.

You will also have to create a Kubernetes service account (KSA) and reference the client ID as well in its annotations. You can see an example of this in [`nginx-wi-deploy.yaml`](./nginx-wi-deploy.yaml).


## Example
```
root@nginx-bb68457f9-79xnr:/# df -h
Filesystem                                                        Size  Used Avail Use% Mounted on
overlay                                                           124G   23G  102G  18% /
tmpfs                                                              64M     0   64M   0% /dev
//azurefilessac84a.privatelink.file.core.windows.net/myfileshare  101G     0  101G   0% /mnt/azure
/dev/root                                                         124G   23G  102G  18% /etc/hosts
shm                                                                64M     0   64M   0% /dev/shm
tmpfs                                                             5.3G   12K  5.3G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                                                             3.9G     0  3.9G   0% /proc/acpi
tmpfs                                                             3.9G     0  3.9G   0% /proc/scsi
tmpfs                                                             3.9G     0  3.9G   0% /sys/firmware
```

```
root@nginx-bb68457f9-79xnr:/# nslookup azurefilessac84a.privatelink.file.core.windows.net
Server:		10.11.0.10
Address:	10.11.0.10#53

Non-authoritative answer:
Name:	azurefilessac84a.privatelink.file.core.windows.net
Address: 192.168.0.4
```


## Additional notes
- you **CANNOT** migrate from using Kubelet identity to Workload Identity.  And this is because the PV's spec is immutable once created, but in order to use Workload Identity, you need to add the WI user's client ID as a parameter in the PV's spec.
- if you specify a `spec.claimRef` in your PV definition, a lot of the settings won't matter (`spec.storageClassName`, `spec.capacity.storage`)
- `spec.capacity.storage` will always take the size of the fileshare (think of it like an NFS export -- you get the entire export, not just a slice)
- `spec.accessModes` won't matter because the fileshare is RW.  You would only be able to mount the volume in RO mode if `spec.template.spec.containers.volumeMounts.readOnly` is set to `false`
- mount options such as `dir_mode`, `file_mode`, `uid`, and `gid` will be ignored if specified in Storage Class.  You will need to set these config options in `spec.mountOptions` at the Persistent Volume level
