#!/usr/bin/env bash
# =============================================================================
# scripts/manifiesto.sh — Escribe el manifiesto del tracer (ADR 25).
#
# El freeze del tracer queda identificado conjuntamente por: tag Git, SHA del
# commit etiquetado, versión contractual coordinada de los artefactos Go y TS, y
# checksums de las fuentes y de los artefactos generados. Este script produce ese
# manifiesto en manifiesto/tracer.manifest.json.
#
# Una rama, ruta local o el nombre de versión sin SHA/checksums NO constituyen
# evidencia del freeze. Este manifiesto es esa evidencia.
#
# Los checksums cubren tres clases, porque congelan cosas distintas:
#   - fuentes: lo que se EDITA (contratos OpenAPI, .proto, catálogos). Es el
#     contrato.
#   - artefactos_go / artefactos_ts: lo que se GENERA. Sin ellos, el manifiesto
#     no ata el tag a los clientes que los consumidores van a compilar, que es
#     justo el defecto de tracer.1: el tag resolvía pero no traía nada
#     importable.
#
# Los *.gen.* se versionan (decisión de owner, 2026-10-02), así que sus bytes son
# parte del freeze y pueden hashearse.
#
# El manifiesto se verifica con scripts/verificar-manifiesto.sh.
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

# Emite una línea de checksum por archivo, en el orden en que se leen por la
# entrada estándar. Ordenar aquí (y no antes) evita que el llamador tenga que
# conocer el detalle de la selección de archivos.
#
#   checksums_de <clase> <selector de find>
#
# Se imprime JSON con coma al final de cada elemento; quien llama quita la
# última. Separar la coma del valor importa: un nombre de archivo con " o \ lo
# rompería, y el JSON silenciosamente inválido es peor que ningún manifiesto.
emite() {
  local clase="$1"
  shift
  local f
  while read -r f; do
    [ -n "$f" ] || continue
    [ -f "$f" ] || continue
    printf '    {"clase": "%s", "archivo": "%s", "sha256": "%s"},\n' \
      "$clase" "$f" "$(shasum -a 256 "$f" | awk '{print $1}')"
  done
}

# Fuentes contractuales: lo que congela el contrato.
fuentes() {
  find contracts -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.proto' -o -name '*.md' \) \
    | LC_ALL=C sort
}

# Cliente Go publicado. Todo *.go del módulo, incluido doc.go y los *.pb.go.
artefactos_go() {
  find packages/api-client-go -type f -name '*.go' | LC_ALL=C sort
}

# Paquete TS publicado. Se incluye package.json y tsconfig.json (son parte de lo
# que npm publica y resuelven los exports) pero no package-lock.json ni
# node_modules: el lock depende del registry en el momento de la resolución y
# node_modules no se publica.
artefactos_ts() {
  find packages/api-client-ts \
    -type d -name node_modules -prune -o \
    -type f \( -name '*.ts' -o -name '*.json' \) ! -name 'package-lock.json' -print \
    | LC_ALL=C sort
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
  echo '    "go_tag": "packages/api-client-go/'"$VERSION"'",'
  echo '    "npm_package": "@ai27-tech/contracts"'
  echo '  },'
  echo '  "checksums": ['
  { fuentes | emite fuentes
    artefactos_go | emite artefactos_go
    artefactos_ts | emite artefactos_ts
  } | sed '$ s/,$//'
  echo '  ]'
  echo '}'
} > "$OUT"

n_fuentes=$(fuentes | wc -l | tr -d ' ')
n_go=$(artefactos_go | wc -l | tr -d ' ')
n_ts=$(artefactos_ts | wc -l | tr -d ' ')

echo "Escrito $OUT (tag=$TAG sha=${SHA:0:12})"
echo "  fuentes=$n_fuentes artefactos_go=$n_go artefactos_ts=$n_ts"

# El manifiesto que no se puede leer no es evidencia de nada: falla aquí, no en
# el paso siguiente del pipeline.
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$OUT" \
  || { echo "ERROR: el manifiesto no es JSON válido." >&2; exit 1; }
