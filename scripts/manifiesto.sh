#!/usr/bin/env bash
# =============================================================================
# scripts/manifiesto.sh — Escribe el manifiesto del tracer (ADR 25).
#
# El freeze del tracer queda identificado conjuntamente por: tag Git, SHA del
# commit etiquetado, versión contractual coordinada de los artefactos Go y TS, y
# checksums de las fuentes y artefactos. Este script produce ese manifiesto en
# manifiesto/tracer.manifest.json.
#
# Una rama, ruta local o el nombre de versión sin SHA/checksums NO constituyen
# evidencia del freeze. Este manifiesto es esa evidencia.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

VERSION="$(cat VERSION)"
TAG="$VERSION"
SHA="$(git rev-parse HEAD)"
FECHA="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OUT="manifiesto/tracer.manifest.json"
mkdir -p manifiesto

# Checksums de las fuentes contractuales (lo que congela el contrato).
checksums_de() {
  # Ordena por ruta para que el manifiesto sea determinista.
  find "$1" -type f \( -name '*.yaml' -o -name '*.proto' -o -name '*.md' \) \
    | LC_ALL=C sort \
    | while read -r f; do
        printf '    {"archivo": "%s", "sha256": "%s"},\n' "$f" "$(shasum -a 256 "$f" | awk '{print $1}')"
      done
}

{
  echo '{'
  printf '  "version_contractual": "%s",\n' "$VERSION"
  printf '  "tag": "%s",\n' "$TAG"
  printf '  "sha": "%s",\n' "$SHA"
  printf '  "generado_en": "%s",\n' "$FECHA"
  echo '  "alcance": "tracer-vertical-v1",'
  echo '  "artefactos": {'
  echo '    "go_module": "github.com/AI27-Tech/pf-pkg-contracts/packages/api-client-go",'
  echo '    "npm_package": "@ai27-tech/contracts"'
  echo '  },'
  echo '  "checksums": ['
  # Concatena y quita la última coma para JSON válido.
  { checksums_de contracts; } | sed '$ s/,$//'
  echo '  ]'
  echo '}'
} > "$OUT"

echo "Escrito $OUT (tag=$TAG sha=${SHA:0:12})"
