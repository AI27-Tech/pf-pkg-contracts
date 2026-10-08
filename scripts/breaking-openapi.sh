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
# oasdiff se ancla como dependencia del repo (tools/oasdiff), igual que
# oapi-codegen en tools/openapi-codegen, para que local y CI usen exactamente el
# mismo binario.
OASDIFF="go run github.com/oasdiff/oasdiff"
REDOCLY="npx --yes @redocly/cli@1.25.11"
VERSION="${VERSION:-$(cat VERSION)}"
# Ruta absoluta del tool de gate de rupturas (D4): autoriza SOLO las rupturas
# declaradas en rompimientos/${VERSION}.yaml, y SOLO mientras VERSION las nombre.
GATE_DIR="$RAIZ/tools/breaking-gate"
ROMPIMIENTOS_DIR="$RAIZ/rompimientos"

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
  # Rutas absolutas: se corre desde tools/oasdiff para que el binario.resolve su
  # go.mod, pero los specs se pasan con ruta absoluta porque el subdirectorio de
  # trabajo cambia.
  abs_prev="$(cd "$(dirname "$previo")" && pwd)/$(basename "$previo")"
  abs_actual="$(cd "$(dirname "$actual")" && pwd)/$(basename "$actual")"
  # `--fail-on ERR` es lo que hace que oasdiff salga distinto de cero ante un
  # cambio incompatible; sin él, el diff se imprimiría y el script daría verde.
  salida_oas="$WORK/$s.oasdiff.txt"
  if ( cd tools/oasdiff && $OASDIFF breaking "$abs_prev" "$abs_actual" --format text --fail-on ERR ) >"$salida_oas" 2>&1; then
    cat "$salida_oas"
    echo "        compatible"
  else
    cat "$salida_oas"
    # D4: una ruptura puede ser INTENCIONAL y estar declarada en la allowlist de
    # esta versión. El gate lee la salida de oasdiff y sólo autoriza lo listado;
    # cualquier ruptura no declarada mantiene el fallo.
    if ( cd "$GATE_DIR" && go run . -tipo openapi -servicio "$s" -version "$VERSION" -rompimientos "$ROMPIMIENTOS_DIR" ) <"$salida_oas"; then
      echo "        INCOMPATIBLE pero DECLARADO en rompimientos/$VERSION.yaml (ruptura intencional)."
    else
      echo "        INCOMPATIBLE y NO declarado. Sube la versión, declara la ruptura con su"
      echo "        fuente en rompimientos/$VERSION.yaml, o publica un release de gracia."
      fallos=1
    fi
  fi
done

if [ "$fallos" -ne 0 ]; then
  echo
  echo "ERROR: cambio incompatible de OpenAPI contra $base." >&2
  exit 1
fi

echo "OK: OpenAPI compatible con $base."