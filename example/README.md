# Example manifests

A two-step pipeline: `function-patch-and-transform` composes a Bucket, a
provider-kubernetes Object, and a plain ConfigMap. `function-lifecycle` then
sets `spec.managementPolicies` on the two managed resources.

```shell
# Run the function locally
go run . --insecure --debug
```

```shell
# In another terminal, render an XR. Pick any xr*.yaml file.
make -C example render XR=xr-provision.yaml
```

Render runs without Docker. `make render` starts function-patch-and-transform
on `127.0.0.1:9444` if it isn't running (`make -C example stop` stops it), and
uses the Crossplane binary as the render engine. The top of the
[Makefile](Makefile) says how to install both.

| XR | Mode | Policies on managed resources |
|---|---|---|
| `xr.yaml` | none (Full) | `["*"]` |
| `xr-provision.yaml` | Provision | `[Observe, Create, Update, LateInitialize]` |
| `xr-observe-only.yaml` | ObserveOnly | `[Observe]` |
| `xr-deprovision.yaml` | Deprovision | `[Observe, Create, Delete]` |
| `xr-invalid.yaml` | Orphan | fatal result, nothing rendered |
