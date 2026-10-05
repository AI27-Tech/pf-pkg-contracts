#!/usr/bin/env bash
# =============================================================================
# scripts/breaking-openapi.sh — Breaking check de OpenAPI (C3 del handoff
# tracer.2).
#
# El invariante que cierra este script: "un cambio incompatible de OpenAPI debe
# romper CI contra la última release publicada" (ADR 25, invariante 4). Antes de
# tracer.2 CI sólo corría `buf breaking`, que cubre los EVENTOS; el spec de
# OpenAPI podía cambiar de forma incompatible sin que nada lo notara.
#
# Se comparan los BUNDLES (specs con sus $ref resueltos) — igual que
# `make lint-openapi` — porque un diff sobre el fuente reportaría falsos positivos
# por el hoisting de $ref de redocly. La herramienta queda fijada por versión.
#
# Línea base: el último tag `v*-tracer.*` alcanzado en origin (NO una rama).
# Una rama no es evidencia de freeze. Si no hay ninguna release publicada todavía,
# el script lo dice y sale 0, igual que hace `buf breaking` en el primer release.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

# Fijado por versión: el mismo commit + toolchain deben dar el mismo veredicto.
OASDIFF_VERSION="${OASDIFF_VERSION:-v1.11.7}"
REDOCLY="npx --yes @redocly/cli@1.25.11"

SERVICIOS=(identidad catalogos operacion bff reportes)

# --- Línea base: último tag de tracer publicada -------------------------------
base="$(git tag --list 'v*-tracer.*' --sort=-v:refname | head -1 || true)"
if [ -z "$base" ]; then
  # Puede haber tags sólo en origin (CI con fetch más completo).
  git fetch --no-tags --quiet origin 'refs/tags/v*-tracer.*:refs/tags/v*-tracer.*' 2>/dev/null || true
  base="$(git tag --list 'v*-tracer.*' --sort=-v:refname | head -1 || true)"
fi

if [ -z "$base" ]; then
  echo "No hay ninguna release 'v*-tracer.*' publicada todavía: se omite el"
  echo "breaking check de OpenAPI (primer release, sin línea base)."
  exit 0
fi

if [ "$base" = "$(cat VERSION)" ]; then
  echo "La línea base ($base) es esta misma versión; se compara contra el commit"
  echo "anterior para que el propio release detecte su propia incompatibilidad."
  base_commit="${base}^"
else
  base_commit="$base"
fi

echo "==> breaking check de OpenAPI contra $base (commit ${base_commit:0:12})"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fallos=0

for s in "${SERVICIOS[@]}"; do
  actual="$WORK/$s.actual.yaml"
  previo="$WORK/$s.base.yaml"

  # Bundle del estado actual (mismo camino que lint-openapi).
  $REDOCLY bundle "contracts/openapi/$s.yaml" -o "$actual" >/dev/null

  # Bundle de la línea base, extraído del tag sin tocar el árbol de trabajo.
  base_dir="$WORK/base"
  rm -rf "$base_dir"
  mkdir -p "$base_dir"
  if ! git archive "$base_commit" contracts/openapi | tar -x -C "$base_dir" 2>/dev/null; then
    echo "  $s: la línea base $base no contiene contracts/openapi; se omite."
    continue
  fi
  if ! $REDOCLY bundle "$base_dir/contracts/openapi/$s.yaml" -o "$previo" >/dev/null 2>&1; then
    echo "  $s: el spec de la línea base no se pudo empaquetar; se omite."
    continue
  fi

  if diff -q "$previo" "$actual" >/dev/null; then
    echo "    - $s: sin cambios respecto a $base"
    continue
  fi

  echo "    - $s: cambió; diff de compatibilidad contra $base"
  if npx --yes "oasdiff@${OASDIFF_VERSION}" breaking "$previo" "$actual" --format text; then
    echo "        compatible"
  else
    echo "        INCOMPATIBLE (arriba el detalle). Sube la versión o publica un"
    echo "        release de gracia (expand/contract)."
    fallos=1
  fi
done

if [ "$fallos" -ne 0 ]; then
  echo
  echo "ERROR: cambio incompatible de OpenAPI contra $base." >&2
  exit 1
fi

echo "OK: OpenAPI compatible con $base."