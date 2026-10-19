# Render the example pipeline against your function running locally.
#
#   go run . --insecure --debug                   # terminal 1
#   make -C example render XR=xr-provision.yaml   # terminal 2
#
# Render runs without Docker. It needs the crossplane CLI (v2.5+) and two
# binaries on your PATH:
#
#   crossplane-core               the Crossplane binary, used as the render engine:
#                                 https://releases.crossplane.io/stable/v2.4.3/bin/<os>_<arch>/crossplane
#   function-patch-and-transform  go install github.com/crossplane-contrib/function-patch-and-transform@v0.11.2
#
# scripts/setup.sh in https://github.com/upbound/crossplane-contribfest-slc
# installs both.

SHELL := /bin/bash

XR ?= xr.yaml
# Render needs the full path to the binary.
CROSSPLANE_BINARY ?= $(shell command -v crossplane-core)
PT ?= function-patch-and-transform
RENDER := crossplane composition render --include-function-results --crossplane-binary=$(CROSSPLANE_BINARY)

.PHONY: render tools pt stop

render: pt
	$(RENDER) $(XR) composition.yaml functions.yaml

tools:
	@[ -x "$(CROSSPLANE_BINARY)" ] || { echo "crossplane-core isn't on your PATH. See the top of example/Makefile."; exit 1; }
	@for t in crossplane $(PT); do \
	  command -v $$t >/dev/null || { echo "$$t isn't on your PATH. See the top of example/Makefile."; exit 1; }; \
	done

# Start function-patch-and-transform on 127.0.0.1:9444 in the background, unless
# it's already running. It keeps running until make stop.
pt: tools
	@(exec 3<>/dev/tcp/127.0.0.1/9444) 2>/dev/null || { \
	  echo "Starting $(PT) on 127.0.0.1:9444. make stop stops it."; \
	  nohup $(PT) --insecure --address=127.0.0.1:9444 >/tmp/function-patch-and-transform.log 2>&1 & \
	  for i in $$(seq 1 40); do (exec 3<>/dev/tcp/127.0.0.1/9444) 2>/dev/null && break; sleep 0.25; done; }

stop:
	-pkill -f "$(PT) --insecure --address=127.0.0.1:9444"
