# Azure Container Storage (ACS)

At the time of writing, [ACS](https://azure.microsoft.com/en-us/products/container-storage) is still in **Preview** status.

## Pre-requisites
- many of the setup commands need to be done via Azure CLI, which also needs the *k8s-extension* installed:
```sh
az extension add -n k8s-extension
```

- node type/series needs to support Premium Storage (i.e. [DSv2-series](https://learn.microsoft.com/en-us/azure/virtual-machines/dv2-dsv2-series#dsv2-series))
- node size needs to have 4+ vCPUs (i.e. Standard_DS3_v2 with 4vCPUs/14GB mem)
- node count needs to be 3+

**NOTE:** you may have to [increase your regional compute quotas](https://learn.microsoft.com/en-us/azure/quotas/regional-quota-requests) **for your specific family of vCPUs** on your Azure account if you are looking to test this out on your personal account


## Setup
The follow command takes ~15 min to run, so be patient:
```sh
az aks update --cluster-name playground-aks-1 \
  --resource-group playground-aks-1-rg \
  --enable-azure-container-storage <storage-pool-type>
```
where `<storage-pool-types>` can be `azureDisk`, `ephemeralDisk`, or `elasticSan`, some of which requires additiona perms/access.  We'll stick with the most general/common use one: `azureDisk`

**NOTE:** you may have label your node pool(s) prior to running the command below if you have multiple ones, for the example here, we only have one (default) node pool and it will get updated with the label (**acstor.azure.com/io-engine: acstor**) automatically


## How-to use ACS
### Storage Pool
There should a a 512Gi *azuredisk* storage pool (sp) in the *acstor* namespace that got created automatically as part of the setup which you can choose to delete if you wish (`kubectl delete sp azuredisk -n acstor`):

- create storage pool:
```sh
kubectl apply -f acstor-azdisk-sp.yaml
```

- sample `kubectl get sp -n acstor` output:
```
NAME        CAPACITY       AVAILABLE      USED         RESERVED      READY   AGE
azdisk-sp   107374182400   106285674496   1088507904   11519455232   True    5m52s
```

**NOTE:** create a storage pool also creates a storage class (with `acstor-` prefix) using default settings.  If you wanted other settings, create your own :)

- sample `kubectl describe sc acstor-azdisk-sp` output:
```
Name:                  acstor-azdisk-sp
IsDefaultClass:        No
Annotations:           <none>
Provisioner:           containerstorage.csi.azure.com
Parameters:            acstor.azure.com/storagepool=azdisk-sp,ioTimeout=60,proto=nvmf,repl=1
AllowVolumeExpansion:  True
MountOptions:          <none>
ReclaimPolicy:         Delete
VolumeBindingMode:     WaitForFirstConsumer
Events:                <none>
```

### Persistent Volume Claim
- create PVC using ACS storage class
```sh
kubectl apply -f acstor-pvc.yaml
```

- sample `kubectl describe pvc acstor-pvc` output:
```
Name:          acstor-pvc
Namespace:     default
StorageClass:  acstor-azdisk-sc
Status:        Pending
Volume:
Labels:        <none>
Annotations:   <none>
Finalizers:    [kubernetes.io/pvc-protection]
Capacity:
Access Modes:
VolumeMode:    Filesystem
Used By:       <none>
Events:
  Type    Reason                Age              From                         Message
  ----    ------                ----             ----                         -------
  Normal  WaitForFirstConsumer  7s (x2 over 9s)  persistentvolume-controller  waiting for first consumer to be created before binding
```


## Testing
At this point, your workloads can utilize the storage just like any other PVC/PV, but I've included a sample pod pod deployment which you can use to run [fio](https://github.com/axboe/fio) to conduct I/O benchmark and stress tests:
```sh
kubectl apply -f fio-pod.yaml
```

- exec into pod and run:
```sh
fio --name=acsbenchtest --size=800m --filename=/mnt/acsvolume/test --direct=1 --rw=randrw --ioengine=libaio --bs=4k --iodepth=16 --numjobs=8 --time_based --group_reporting --runtime=60
```

- sample output:
```
fio-3.36
Starting 8 processes
Jobs: 8 (f=8): [m(8)][100.0%][r=11.2MiB/s,w=11.4MiB/s][r=2873,w=2923 IOPS][eta 00m:00s]
acsbenchtest: (groupid=0, jobs=8): err= 0: pid=26: Fri Jun 28 23:10:16 2024
  read: IOPS=2897, BW=11.3MiB/s (11.9MB/s)(680MiB/60051msec)
    slat (usec): min=2, max=64046, avg=1259.07, stdev=5206.04
    clat (usec): min=219, max=102828, avg=16576.00, stdev=15933.70
     lat (usec): min=1476, max=105496, avg=17835.07, stdev=16434.02
    clat percentiles (usec):
     |  1.00th=[ 1795],  5.00th=[ 2147], 10.00th=[ 2606], 20.00th=[ 3818],
     | 30.00th=[ 4948], 40.00th=[ 6259], 50.00th=[ 7767], 60.00th=[10159],
     | 70.00th=[30278], 80.00th=[34866], 90.00th=[40109], 95.00th=[46400],
     | 99.00th=[54789], 99.50th=[56886], 99.90th=[63177], 99.95th=[66847],
     | 99.99th=[85459]
   bw (  KiB/s): min= 8459, max=15048, per=100.00%, avg=11610.52, stdev=158.97, samples=952
   iops        : min= 2114, max= 3762, avg=2902.51, stdev=39.75, samples=952
  write: IOPS=2899, BW=11.3MiB/s (11.9MB/s)(680MiB/60051msec); 0 zone resets
    slat (usec): min=3, max=77115, avg=1280.62, stdev=5271.39
    clat (usec): min=1912, max=107331, avg=25032.11, stdev=17737.07
     lat (msec): min=2, max=110, avg=26.31, stdev=17.97
    clat percentiles (msec):
     |  1.00th=[    3],  5.00th=[    5], 10.00th=[    6], 20.00th=[    8],
     | 30.00th=[   10], 40.00th=[   12], 50.00th=[   20], 60.00th=[   36],
     | 70.00th=[   39], 80.00th=[   42], 90.00th=[   48], 95.00th=[   54],
     | 99.00th=[   62], 99.50th=[   66], 99.90th=[   90], 99.95th=[   96],
     | 99.99th=[  102]
   bw (  KiB/s): min= 8885, max=14508, per=100.00%, avg=11608.50, stdev=136.57, samples=952
   iops        : min= 2221, max= 3627, avg=2902.02, stdev=34.14, samples=952
  lat (usec)   : 250=0.01%, 500=0.01%, 750=0.01%
  lat (msec)   : 2=1.65%, 4=10.90%, 10=34.39%, 20=11.52%, 50=36.26%
  lat (msec)   : 100=5.27%, 250=0.01%
  cpu          : usr=0.36%, sys=1.18%, ctx=326095, majf=0, minf=96
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=100.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.1%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=174025,174090,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=16

Run status group 0 (all jobs):
   READ: bw=11.3MiB/s (11.9MB/s), 11.3MiB/s-11.3MiB/s (11.9MB/s-11.9MB/s), io=680MiB (713MB), run=60051-60051msec
  WRITE: bw=11.3MiB/s (11.9MB/s), 11.3MiB/s-11.3MiB/s (11.9MB/s-11.9MB/s), io=680MiB (713MB), run=60051-60051msec

Disk stats (read/write):
  nvme0n1: ios=0/0, sectors=0/0, merge=0/0, ticks=0/0, in_queue=0, util=0.00%
```
