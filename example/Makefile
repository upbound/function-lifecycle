# Render the examples against function-lifecycle running locally.
#
#   make test                          # build and start the function, render every example, report PASS/FAIL
#   make serve                         # run the function in the foreground, with debug logs
#   make render XR=xr-provision.yaml   # render one XR (start the function first: make serve, or go run)
#   make stop                          # stop function-patch-and-transform
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
COMPOSITION ?= composition.yaml
# Pipeline context, e.g. CONTEXT='apiextensions.crossplane.io/environment={"managementMode":"Deprovision"}'
CONTEXT ?=
# Render needs the full path to the binary.
CROSSPLANE_BINARY ?= $(shell command -v crossplane-core)
PT ?= function-patch-and-transform
export CROSSPLANE_BINARY

ROOT := ..
BIN ?= /tmp/function-lifecycle-render
RENDER := crossplane composition render --include-function-results --crossplane-binary=$(CROSSPLANE_BINARY)

.PHONY: render test serve build tools pt stop clean

render: pt
	$(RENDER) $(XR) $(COMPOSITION) functions.yaml $(if $(CONTEXT),--context-values='$(CONTEXT)')

test: build pt
	@./test.sh $(BIN)

serve: build pt
	$(BIN) --insecure --debug --address=127.0.0.1:9443

build: $(BIN)

$(BIN): $(wildcard $(ROOT)/*.go) $(wildcard $(ROOT)/input/v1beta1/*.go)
	cd $(ROOT) && go build -o $(BIN) .

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

clean: stop
	rm -f $(BIN) /tmp/render-*.out /tmp/function-lifecycle-render.log /tmp/function-patch-and-transform.log
