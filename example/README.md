# Example manifests

A two-step pipeline:

1. `function-patch-and-transform` composes a Bucket, a provider-kubernetes
   Object, and a plain ConfigMap.
2. `function-lifecycle` sets `spec.managementPolicies` on the two managed
   resources and skips the ConfigMap.

```shell
# Build, start, render every example, and report PASS/FAIL.
make -C example test
```

To render one XR by hand, run the function in one terminal and render in another:

```shell
make -C example serve                          # function with debug logs
make -C example render XR=xr-provision.yaml    # any xr*.yaml file
```

Render runs without Docker. `make` starts function-patch-and-transform on
`127.0.0.1:9444` if it isn't running (`make -C example stop` stops it), and
uses the Crossplane binary as the render engine. The top of the
[Makefile](Makefile) says how to install both.

| XR | Mode | Policies on managed resources |
|---|---|---|
| `xr.yaml` | Full, from the input's `mode` | `["*"]` |
| `xr-provision.yaml` | Provision, from the annotation | `[Observe, Create, Update, LateInitialize]` |
| `xr-observe-only.yaml` | ObserveOnly, from the annotation | `[Observe]` |
| `xr-deprovision.yaml` | Deprovision, from the annotation | `[Observe, Create, Delete]` |
| `xr-spec-mode.yaml` | ObserveOnly, from `spec.parameters.managementMode` via `modeRef` | `[Observe]` |
| `xr-invalid.yaml` | Orphan | fatal result, nothing rendered |

The annotation always wins. Without it, `modeRef` is read, then the input's
`mode`, then `Full`.

To drive the mode from the pipeline context, for example an EnvironmentConfig
loaded by function-environment-configs, use `composition-environment.yaml`:

```shell
make -C example render COMPOSITION=composition-environment.yaml \
  CONTEXT='apiextensions.crossplane.io/environment={"managementMode":"Deprovision"}'
```

## Debugging

* `--include-function-results` (`-r`) prints each step's results. The Makefile
  always passes it.
* `--include-context` (`-c`) prints the pipeline context as `kind: Context`.
* `--include-full-xr` (`-x`) prints the full XR, including the `LifecycleMode`
  condition this function sets.
* `make serve` runs the function with `--debug`, which logs each resource it
  changes or skips.

With `make serve` running, you can call render yourself with any of these flags:

```shell
cd example
crossplane composition render xr-observe-only.yaml composition.yaml functions.yaml \
  --crossplane-binary=$(which crossplane-core) -r -x
```
