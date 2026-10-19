# function-lifecycle
[![CI](https://github.com/upbound/function-lifecycle/actions/workflows/ci.yml/badge.svg)](https://github.com/upbound/function-lifecycle/actions/workflows/ci.yml)

A [composition function][functions] that sets the lifecycle mode of every
composed managed resource (MR) in one place.

Crossplane v2 namespaced MRs have no `deletionPolicy`. Their
[`managementPolicies`][policies] decide what Crossplane may do: observe, create,
update, delete, or late-initialize. Instead of patching that field into every
resource of every composition, add this function as the last step of the
pipeline and pick a mode.

| Mode | `managementPolicies` | Use it to |
|---|---|---|
| `Full` (default) | `["*"]` | Manage the whole lifecycle. Standard Crossplane behavior. |
| `Provision` | `[Observe, Create, Update, LateInitialize]` | Create, import, and update, but never delete. Deleting the XR orphans its external resources. |
| `ObserveOnly` | `[Observe]` | Import and watch without changing anything. Safe takeover or change freeze. |
| `Deprovision` | `[Observe, Create, Delete]` | Import and delete without reconciling drift. Decommissioning. |

## Usage

Add the function after the steps that compose resources:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: apps.example.crossplane.io
spec:
  compositeTypeRef:
    apiVersion: example.crossplane.io/v1
    kind: App
  mode: Pipeline
  pipeline:
  - step: compose
    functionRef:
      name: function-patch-and-transform
    input: {} # Your resources
  - step: lifecycle
    functionRef:
      name: function-lifecycle
    input:
      apiVersion: lifecycle.fn.crossplane.io/v1beta1
      kind: Input
      mode: Full                               # Optional. Defaults to Full.
      modeRef: spec.parameters.managementMode  # Optional.
```

The function picks the mode from the first of these that's set:

1. The XR annotation `lifecycle.fn.crossplane.io/mode`. Operators can always
   override the mode with `kubectl annotate`.
2. The field `modeRef` points to. It must start with `spec.`, `status.`, or
   `context.`. Use brackets for keys that contain dots, for example
   `context.[apiextensions.crossplane.io/environment].managementMode` to read
   an EnvironmentConfig loaded by [function-environment-configs][envconfigs].
3. The input's `mode`.
4. `Full`.

An unknown mode is a fatal error. The function never falls back to `Full` when
a mode is misspelled.

The function reports the active mode in an event and in the XR's
`LifecycleMode` condition:

```console
$ crossplane resource trace app my-app
```

### Recipes

Freeze changes to an XR's resources during an incident:

```shell
kubectl annotate app my-app lifecycle.fn.crossplane.io/mode=ObserveOnly
# Undo it
kubectl annotate app my-app lifecycle.fn.crossplane.io/mode-
```

Delete an XR but keep its cloud resources, for example to move them to another
control plane:

```shell
kubectl annotate app my-app lifecycle.fn.crossplane.io/mode=Provision
# Wait until the composed resources show the new policies and are Synced.
kubectl get managed -l crossplane.io/composite=my-app
kubectl delete app my-app
```

> [!IMPORTANT]
> Crossplane applies the new policies on the next reconcile. Wait for it before
> you delete the XR, or Crossplane deletes the external resources.

### What the function changes

* It only changes desired resources that have `spec.forProvider`, which every
  MR has. Plain Kubernetes objects and nested XRs are skipped.
* It overwrites `spec.managementPolicies` set by earlier pipeline steps.
* The provider must support management policies. They're on by default in the
  upjet providers and provider-kubernetes, and off by default in the classic
  crossplane-contrib/provider-aws.

## Developing

```shell
# Generate the input CRD - see input/generate.go
go generate ./...

# Run unit tests - see fn_test.go
go test ./...

# Render every example and report PASS/FAIL - see example/
make -C example test

# Build the runtime image and the package. Needs Docker with BuildKit.
docker build . --tag=runtime
crossplane xpkg build -f package --embed-runtime-image=runtime
```

`make -C example test` doesn't need Docker. It runs the Crossplane binary as
the render engine and function-patch-and-transform as a local process. The top
of [example/Makefile](example/Makefile) says how to install both.

## Related

* [crossplane/crossplane#7367][pr7367] proposes `managementPoliciesOptions`,
  an XR-level switch to orphan resources on delete.

[functions]: https://docs.crossplane.io/latest/composition/compositions/
[policies]: https://docs.crossplane.io/latest/managed-resources/managed-resources/#managementpolicies
[envconfigs]: https://github.com/crossplane-contrib/function-environment-configs
[pr7367]: https://github.com/crossplane/crossplane/pull/7367
