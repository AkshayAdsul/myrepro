# Edge Portal Delete Issue Reproducer

This repository serves as a reproducer for [the Edge portal issue that Airtel is running into](https://github.com/solo-io/dev-portal/issues/3028).

## Setup Instructions

Start by setting up the cluster

```bash
./setup-kind-gloo.sh
```

This script will set up a Kind cluster with Gloo Edge and Gloo Portal. 
It will also deploy `environmentNum` `Environments`, each containing `apiProductsPerEnvironment` distinct `ApiProducts`, each of which in turn point to a distinct `ApiDoc`.

## Issue reproduction

In separate terminals you can start the following watches:

```shell
kubectl get virtualservices -A -w
kubectl get routetables -A -w
kubectl get environments -A -w -oyaml | grep "state:"
kubectl get apiproduct -A -w -oyaml | grep "state:"
kubectl get apidoc -A -w -oyaml | grep "state:"
```

### 1.4.2 pod restart

```shell
kubectl rollout restart deployment -n gloo-system gloo-portal-controller
```

After you restart the pod, you should see `Environments` temporarily going into a `Failed` state.
The Edge outputs, however, are stable.

### Upgrade to 1.4.12
```shell
helm upgrade --install gloo-portal gloo-portal/gloo-portal --version 1.4.12 -n gloo-system --values portal-values.yaml
```

If you instead upgrade Portal to 1.4.12, you will see that `RouteTables` are getting deleted and recreated.
Interestingly, `Environments` now go into a temporary `Processing` state instead of `Failed`.

### 1.4.12 pod restart

```shell
kubectl rollout restart deployment -n gloo-system gloo-portal-controller
```

If you restart the pod on 1.4.12, you should see the same behavior as on upgrade.