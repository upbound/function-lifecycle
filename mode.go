package main

import (
	"github.com/crossplane/function-sdk-go/errors"
)

// Mode is a lifecycle mode. Each mode maps to a set of management policies
// that crossplane-runtime supports.
type Mode string

// Supported lifecycle modes.
const (
	// ModeFull lets Crossplane manage the entire lifecycle, including deletion.
	ModeFull Mode = "Full"

	// ModeProvision creates, imports, and updates resources but never deletes
	// them. Deleting the XR orphans the external resources.
	ModeProvision Mode = "Provision"

	// ModeObserveOnly imports and watches resources without changing them.
	ModeObserveOnly Mode = "ObserveOnly"

	// ModeDeprovision imports and deletes resources without reconciling drift.
	ModeDeprovision Mode = "Deprovision"
)

var policies = map[Mode][]string{
	ModeFull:        {"*"},
	ModeProvision:   {"Observe", "Create", "Update", "LateInitialize"},
	ModeObserveOnly: {"Observe"},
	ModeDeprovision: {"Observe", "Create", "Delete"},
}

// Policies returns the management policies for the mode.
func (m Mode) Policies() ([]string, error) {
	p, ok := policies[m]
	if !ok {
		return nil, errors.Errorf("unknown mode %q: must be one of Full, Provision, ObserveOnly, Deprovision", m)
	}
	return p, nil
}
