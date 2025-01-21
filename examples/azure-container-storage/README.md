# Azure Container Storage (ACS)

At the time of writing, [ACS](https://azure.microsoft.com/en-us/products/container-storage) is ~~still in **Preview** status.~~ [GA as of July 30, 2024](https://azure.microsoft.com/en-us/blog/embrace-the-future-of-container-native-storage-with-azure-container-storage/)

**NOTE:** some of the setup steps/commands via Azure CLI below are only required if you did not enable the ACS extension in the Terraform deployment

## Pre-requisites
- many of the setup commands need to be done via Azure CLI, which also needs the *k8s-extension* installed:
```sh
az extension add -n k8s-extension
```

- node type/series needs to support Premium Storage (i.e. [DSv2-series](https://learn.microsoft.com/en-us/azure/virtual-machines/dv2-dsv2-series#dsv2-series))
- node size needs to have 4+ vCPUs (i.e. Standard_DS3_v2 with 4vCPUs/14GB mem)
- node count needs to be 3+
- Azure Disk CSI driver (if you're using Azure Disk as backend storage)

**NOTE:** you may have to [increase your regional compute quotas](https://learn.microsoft.com/en-us/azure/quotas/regional-quota-requests) **for your specific family of vCPUs** on your Azure account if you are looking to test this out on your personal account


## Setup
The follow command takes ~15 min to run, so be patient:
```sh
az aks update --name playground-aks-1 \
  --resource-group playground-aks-1-rg \
  --enable-azure-container-storage <storage-pool-type>
```
where `<storage-pool-types>` can be `azureDisk`, `ephemeralDisk`, or `elasticSan`, some of which requires additiona perms/access.  We'll stick with the most general/common use one: `azureDisk`

**NOTE:** you may have to label your node pool(s) prior to running the command below if you have multiple ones, for the example here, we only have one (default) node pool and it will get updated with the label, `acstor.azure.com/io-engine: acstor` automatically


## How-to use ACS
### Storage Pool
- create storage pool:
```sh
kubectl apply -f acstor-azdisk-sp.yaml
```

- sample `kubectl get sp -n acstor` output:
```
NAME        CAPACITY       AVAILABLE      USED         RESERVED      READY   AGE
azdisk-sp   107374182400   106285674496   1088507904   11519455232   True    5m52s
```

**NOTE:** create a storage pool also creates a storage class (with `acstor-` prefix) using default settings.  If you wanted bespoke settings, you'll have to create your own.

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

**NOTE:** You can create additional volume slices from the same Storage Pool (provided there's sufficient storage available)


## Performance Testing
At this point, your workloads can utilize the storage just like any other PVC/PV, but I've included a sample pod pod deployment which you can use to run [fio](https://github.com/axboe/fio) to conduct I/O benchmark and stress tests:
```sh
kubectl apply -f fio-pod.yaml
```

- exec into pod and run:
```sh
fio --name=acsbenchtest --size=800m --filename=/mnt/acsvolume/test --direct=1 --rw=randrw --ioengine=libaio --bs=4k --iodepth=16 --numjobs=8 --time_based --group_reporting --runtime=60
```

- sample output (note the ~5k IOPS on a 10GB volume!!):
```
fio-3.38
Starting 8 processes
acsbenchtest: Laying out IO file (1 file / 800MiB)
Jobs: 8 (f=8): [m(8)][100.0%][r=20.2MiB/s,w=19.6MiB/s][r=5176,w=5015 IOPS][eta 00m:00s]
acsbenchtest: (groupid=0, jobs=8): err= 0: pid=16: Tue Jan 21 04:26:14 2025
  read: IOPS=4982, BW=19.5MiB/s (20.4MB/s)(1168MiB/60007msec)
    slat (usec): min=2, max=2028.1k, avg=765.63, stdev=9796.22
    clat (usec): min=78, max=2033.7k, avg=10252.44, stdev=28905.76
     lat (usec): min=296, max=2035.8k, avg=11018.06, stdev=30446.73
    clat percentiles (usec):
     |  1.00th=[    840],  5.00th=[   1483], 10.00th=[   1778],
     | 20.00th=[   2311], 30.00th=[   2868], 40.00th=[   3523],
     | 50.00th=[   4228], 60.00th=[   5145], 70.00th=[   6587],
     | 80.00th=[  16188], 90.00th=[  32637], 95.00th=[  36963],
     | 99.00th=[  47449], 99.50th=[  49546], 99.90th=[  59507],
     | 99.95th=[  67634], 99.99th=[2021655]
   bw (  KiB/s): min= 3626, max=31904, per=100.00%, avg=20497.39, stdev=342.20, samples=926
   iops        : min=  906, max= 7976, avg=5124.06, stdev=85.56, samples=926
  write: IOPS=4976, BW=19.4MiB/s (20.4MB/s)(1166MiB/60007msec); 0 zone resets
    slat (usec): min=2, max=2022.6k, avg=734.33, stdev=6404.34
    clat (usec): min=120, max=2549.6k, avg=13951.28, stdev=34268.00
     lat (usec): min=1040, max=2549.7k, avg=14685.62, stdev=34772.07
    clat percentiles (msec):
     |  1.00th=[    3],  5.00th=[    3], 10.00th=[    4], 20.00th=[    4],
     | 30.00th=[    5], 40.00th=[    6], 50.00th=[    7], 60.00th=[    8],
     | 70.00th=[   11], 80.00th=[   31], 90.00th=[   36], 95.00th=[   41],
     | 99.00th=[   51], 99.50th=[   53], 99.90th=[   67], 99.95th=[   72],
     | 99.99th=[ 2039]
   bw (  KiB/s): min=  304, max=30080, per=100.00%, avg=20424.62, stdev=346.09, samples=928
   iops        : min=   76, max= 7520, avg=5105.88, stdev=86.53, samples=928
  lat (usec)   : 100=0.01%, 250=0.01%, 500=0.07%, 750=0.29%, 1000=0.48%
  lat (msec)   : 2=6.71%, 4=26.86%, 10=38.77%, 20=3.88%, 50=22.25%
  lat (msec)   : 100=0.68%, 250=0.01%, 500=0.01%, >=2000=0.02%
  cpu          : usr=0.48%, sys=1.61%, ctx=288183, majf=0, minf=95
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=100.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.1%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=298984,298605,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=16

Run status group 0 (all jobs):
   READ: bw=19.5MiB/s (20.4MB/s), 19.5MiB/s-19.5MiB/s (20.4MB/s-20.4MB/s), io=1168MiB (1225MB), run=60007-60007msec
  WRITE: bw=19.4MiB/s (20.4MB/s), 19.4MiB/s-19.4MiB/s (20.4MB/s-20.4MB/s), io=1166MiB (1223MB), run=60007-60007msec

Disk stats (read/write):
  nvme0n1: ios=0/0, sectors=0/0, merge=0/0, ticks=0/0, in_queue=0, util=0.00%
```
