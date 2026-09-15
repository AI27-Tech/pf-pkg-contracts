//go:build tools

// Package tools fija la versión del generador oapi-codegen para que
// `scripts/generar.sh` produzca artefactos reproducibles (ADR 25). No se
// compila en la build normal (build tag `tools`); sólo ancla la dependencia en
// go.mod/go.sum.
package tools

import (
	_ "github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen"
)
