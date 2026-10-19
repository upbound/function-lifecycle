#!/usr/bin/env bash
# Renders every example against a fresh build of function-lifecycle and checks
# the output. Run it with make test, which builds the function and starts
# function-patch-and-transform first.
set -uo pipefail
cd "$(dirname "$0")"

FN=${1:?usage: test.sh <function-lifecycle binary>}
PORT=9443
RENDER=(crossplane composition render --include-function-results --crossplane-binary="${CROSSPLANE_BINARY:-$(command -v crossplane-core)}")
ENV='apiextensions.crossplane.io/environment={"managementMode":"Deprovision"}'

# name|xr|composition|context|expected text in the output (! means render must fail)
EXAMPLES="
default|xr.yaml|composition.yaml||Full (from input mode): set managementPolicies [*] on 2 managed resources (1 skipped)
provision|xr-provision.yaml|composition.yaml||Provision (from annotation lifecycle.fn.crossplane.io/mode): set managementPolicies [Observe Create Update LateInitialize] on 2 managed resources (1 skipped)
observe-only|xr-observe-only.yaml|composition.yaml||ObserveOnly (from annotation lifecycle.fn.crossplane.io/mode): set managementPolicies [Observe] on 2 managed resources (1 skipped)
deprovision|xr-deprovision.yaml|composition.yaml||Deprovision (from annotation lifecycle.fn.crossplane.io/mode): set managementPolicies [Observe Create Delete] on 2 managed resources (1 skipped)
spec-mode|xr-spec-mode.yaml|composition.yaml||ObserveOnly (from modeRef spec.parameters.managementMode)
environment|xr.yaml|composition-environment.yaml|$ENV|Deprovision (from modeRef context.[apiextensions.crossplane.io/environment].managementMode)
invalid|xr-invalid.yaml|composition.yaml||!unknown mode \"Orphan\"
"

listening() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

if listening $PORT; then
  echo "Something is already listening on port $PORT. Stop your go run (Ctrl-C) and try again."
  exit 1
fi

"$FN" --insecure --address=127.0.0.1:$PORT >/tmp/function-lifecycle-render.log 2>&1 &
FN_PID=$!
trap 'kill $FN_PID 2>/dev/null' EXIT
for _ in $(seq 1 40); do listening $PORT && break; sleep 0.25; done

fail=0
while IFS='|' read -r name xr comp context expect; do
  [ -z "$name" ] && continue
  out=/tmp/render-$name.out
  args=("$xr" "$comp" functions.yaml)
  [ -n "$context" ] && args+=(--context-values="$context")
  "${RENDER[@]}" "${args[@]}" >"$out" 2>&1
  rc=$?
  # YAML folds long messages across lines. Squash whitespace before matching.
  flat=$(tr -s ' \n' '  ' <"$out")
  if [[ $expect == !* ]]; then
    [[ $rc -ne 0 && $flat == *"${expect#!}"* ]] && ok=1 || ok=0
  else
    [[ $rc -eq 0 && $flat == *"$expect"* ]] && ok=1 || ok=0
  fi
  if [ $ok -eq 1 ]; then echo "PASS  $name"; else echo "FAIL  $name (see $out)"; fail=1; fi
done <<<"$EXAMPLES"
exit $fail
