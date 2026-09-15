#!/usr/bin/env bash
# =============================================================================
# scripts/generar.sh — Generación reproducible de artefactos Go y TypeScript
# desde las fuentes contractuales. Es el ÚNICO camino de codegen; lo usan tanto
# `make generate` como CI. El mismo commit + toolchain producen los mismos bytes
# (ADR 25: codegen reproducible; los artefactos generados no se editan a mano).
#
# Pasos:
#   1. Estados: contracts/estados -> Go + TS (tools/gen-estados).
#   2. OpenAPI: bundle por servicio -> Go (oapi-codegen) y TS (openapi-typescript).
#   3. Eventos: contracts/events -> Go + TS (buf generate).
#
# Prerrequisitos (fijados por versión en CI):
#   - Go (toolchain del repo)
#   - Node + npx: @redocly/cli, openapi-typescript
#   - buf, y los plugins remotos declarados en buf.gen.yaml
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

OPENAPI_DIR="contracts/openapi"
GO_PKG_DIR="packages/api-client-go"
TS_SRC_DIR="packages/api-client-ts/src"
BUNDLE_DIR="$(mktemp -d)"
trap 'rm -rf "$BUNDLE_DIR"' EXIT

# Servicios del tracer (un spec por servicio). `_comunes.yaml` no es servicio.
SERVICIOS=(identidad catalogos operacion bff reportes)

echo "==> 1/3  Estados (fuente única -> Go + TS)"
( cd tools/gen-estados && go run . \
    -src ../../contracts/estados/viaje.estados.yaml \
    -go ../../"$GO_PKG_DIR"/estados/viaje_estados.gen.go \
    -ts ../../"$TS_SRC_DIR"/estados/viajeEstados.gen.ts )

echo "==> 2/3  OpenAPI (bundle -> Go cliente + TS tipos)"
for s in "${SERVICIOS[@]}"; do
  bundle="$BUNDLE_DIR/$s.bundle.yaml"
  echo "    - bundle $s"
  npx --yes @redocly/cli@1.25.11 bundle "$OPENAPI_DIR/$s.yaml" -o "$bundle" >/dev/null

  echo "    - Go   $s"
  mkdir -p "$GO_PKG_DIR/$s"
  ( cd tools/openapi-codegen && go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen \
      -package "$s" \
      -generate types,client \
      -o ../../"$GO_PKG_DIR/$s/$s.gen.go" \
      "$bundle" )

  echo "    - TS   $s"
  mkdir -p "$TS_SRC_DIR/openapi"
  npx --yes openapi-typescript@7.4.4 "$bundle" -o "$TS_SRC_DIR/openapi/$s.gen.ts" >/dev/null
done

echo "==> 3/3  Eventos (buf generate)"
buf generate

echo "OK  artefactos generados."
