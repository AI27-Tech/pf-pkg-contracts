//go:build tools

// Package tools fija la versión de oasdiff para que el breaking check de OpenAPI
// (scripts/breaking-openapi.sh) sea reproducible y dé el mismo veredicto en
// local y en CI. Sin anclar la versión, un patch del toolchain podría cambiar el
// resultado del diff y romper o (peor) dejar pasar un cambio incompatible.
//
// No se compila en la build normal (build tag `tools`); sólo ancla la
// dependencia en go.mod/go.sum.
package tools

import (
	_ "github.com/oasdiff/oasdiff"
)