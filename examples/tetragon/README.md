# Tracing Policy examples
You can find more in my [GKE repo's examples](https://github.com/Neutrollized/free-tier-gke/tree/master/examples/tetragon).

[Medium article](https://medium.com/azure-terraformer/azure-kubernetes-service-supports-a-powerful-tetragon-feature-a62165d884e1)

## Setup
```console
helm repo add cilium https://helm.cilium.io
helm repo update

helm search repo cilium/tetragon -l

helm install tetragon cilium/tetragon \
  --namespace kube-system \
  --version 1.1.2
```

## Override
The override action is only available to kernels compiled with `CONFIG_BPF_KPROBE_OVERRIDE` set/enabled.  There are a couple of ways to check for this:

1. Check the `/proc/config.gz` file from a pod

or 

2. The more consistent way (I found) is to apply your Tracing Policy with the override action and then run the following from inside a pod:
```
cat /proc/kallsyms | grep kprobe_override
```

If it doesn't return a result, then you probably don't have the setting enabled.


### Kernel Function References
- [sys_linkat](https://elixir.bootlin.com/linux/v4.8/source/fs/namei.c#L4217)
- [sys_write](https://elixir.bootlin.com/linux/v6.11.7/source/fs/read_write.c#L652)
