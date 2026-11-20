#!/usr/bin/env bash
# =============================================================================
# scripts/breaking-eventos.sh — Breaking check de EVENTOS (buf) con allowlist por
# versión (D4 / `tracer.4`).
#
# `buf breaking` sigue siendo la autoridad de compatibilidad de los .proto; este
# envoltorio sólo decide qué hacer con su veredicto: una ruptura pasa SOLO si
# está declarada en `rompimientos/${VERSION}.yaml` y SOLO mientras `VERSION` sea
# esa misma versión. Cualquier ruptura no declarada mantiene el fallo (R5: el
# gate falla ante lo que nadie declaró).
#
# Línea base: la rama principal `pf-contracts-m` (igual que antes, `make
# breaking`). Si no existe o no trae contratos, se omite como en el primer
# release.
#
# `buf` NO resuelve `FETCH_HEAD`: lo trata como `HEAD` y compara el commit contra
# sí mismo, así que `.git#ref=FETCH_HEAD` nunca detecta nada (medido: la salida
# contra `ref=FETCH_HEAD` y contra `ref=HEAD` es idéntica). Por eso este script
# resuelve cualquier `#ref=<ref>` a un SHA antes de llamar a `buf`, y falla si no
# puede resolverlo en vez de comparar contra otra cosa.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

VERSION="${VERSION:-$(cat VERSION)}"
BASE_REF="${1:-.git#branch=pf-contracts-m}"

# Resuelve `#ref=<ref>` a un SHA (ver la nota de arriba). `#branch=` y `#tag=` sí
# los entiende buf y no se tocan.
if [[ "$BASE_REF" =~ ^(.*)#ref=([^,]+)(.*)$ ]]; then
  base_sha="$(git rev-parse --verify --quiet "${BASH_REMATCH[2]}^{commit}" || true)"
  if [ -z "$base_sha" ]; then
    echo "ERROR: no se pudo resolver la línea base '${BASH_REMATCH[2]}' a un commit." >&2
    echo "       Un ref que buf no entiende lo compara contra HEAD y el chequeo queda vacío." >&2
    exit 1
  fi
  BASE_REF="${BASH_REMATCH[1]}#ref=${base_sha}${BASH_REMATCH[3]}"
fi
GATE_DIR="$RAIZ/tools/breaking-gate"
ROMPIMIENTOS_DIR="$RAIZ/rompimientos"

salida="$(mktemp)"
trap 'rm -f "$salida"' EXIT

echo "==> buf breaking de eventos contra ${BASE_REF}"
if buf breaking --against "$BASE_REF" >"$salida" 2>&1; then
  cat "$salida"
  echo "OK: eventos compatibles con ${BASE_REF}."
  exit 0
fi

# buf salió distinto de cero: hubo rupturas (o un error de ejecución). Si fue un
# error de ejecución y no una ruptura, el gate no encontrará líneas de ruptura y
# saldrá verde; por eso se distingue el mensaje de "no hay línea base".
cat "$salida"
if grep -qiE 'no such|does not exist|failed to|could not' "$salida" && ! grep -q ':.*:.*:' "$salida"; then
  echo "No hay línea base de eventos utilizable; se omite el breaking check."
  exit 0
fi

echo "==> hay rupturas de eventos; se contrastan con rompimientos/${VERSION}.yaml"
if ( cd "$GATE_DIR" && go run . -tipo eventos -version "$VERSION" -rompimientos "$ROMPIMIENTOS_DIR" ) <"$salida"; then
  echo "OK: las rupturas de eventos están DECLARADAS en rompimientos/${VERSION}.yaml (intencionales)."
  exit 0
fi

echo "ERROR: ruptura de eventos no declarada contra ${BASE_REF}." >&2
exit 1
