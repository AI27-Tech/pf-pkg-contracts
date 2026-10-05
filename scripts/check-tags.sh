#!/usr/bin/env bash
# =============================================================================
# scripts/check-tags.sh — El módulo Go publicado debe traer TODOS los paquetes.
#
# Por qué existe: `v0.1.0-tracer.1` se retiró precisamente porque el tag del
# módulo Go no contenía los clientes generados (el .gitignore los excluía y CI
# sólo generaba en el runner). El tag era un artefacto vacío: `go get` no daba
# nada importable. Este script convierte ese defecto en un fallo de CI, en vez de
# en un retiro de release.
#
# Verifica el árbol REAL de lo que se publica, con `git ls-tree`, no el árbol de
# trabajo. Corre dos veces:
#   - en `verificar`, contra el commit que se está por publicar;
#   - en `publicar`, contra el commit YA etiquetado (que es la evidencia).
#
# Cada paquete debe tener al menos un archivo versionado; sólo tener el directorio
# vacío no cuenta.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

# Se puede pasar un ref explícito (el SHA etiquetado en el job publicar).
REF="${1:-HEAD}"

GO_DIR="packages/api-client-go"

# Paquetes que el módulo Go debe publicar. Los seis clientes HTTP/tipo más el
# sobre común y el registro de tipos de evento.
PAQUETES=(
  identidad
  catalogos
  operacion
  bff
  reportes
  eventos
  estados
  registro
  roles
)

fallos=0

echo "==> Contenido del árbol de $GO_DIR en $REF"

for p in "${PAQUETES[@]}"; do
  n="$(git ls-tree -r --name-only "$REF" -- "$GO_DIR/$p" | wc -l | tr -d ' ')"
  if [ "$n" -eq 0 ]; then
    echo "  FALTA  $GO_DIR/$p  (0 archivos versionados en el tag)"
    fallos=1
  else
    echo "  ok     $GO_DIR/$p  ($n archivos)"
  fi
done

# El tag prefijado que Go resuelve para el módulo anidado debe apuntar al mismo
# commit que el release. Si difieren, los consumidores fijan una versión cuyo
# contenido no es el congelado.
tag_prefijado="packages/api-client-go/$(cat VERSION)"
if git rev-parse -q --verify "refs/tags/$tag_prefijado" >/dev/null; then
  sha_tag="$(git rev-parse "refs/tags/$tag_prefijado^{commit}")"
  sha_ref="$(git rev-parse "$REF^{commit}")"
  if [ "$sha_tag" != "$sha_ref" ]; then
    echo "  FALTA  el tag $tag_prefijado apunta a ${sha_tag:0:12}, no a ${sha_ref:0:12}"
    fallos=1
  else
    echo "  ok     el tag $tag_prefijado apunta al mismo commit"
  fi
fi

if [ "$fallos" -ne 0 ]; then
  echo
  echo "ERROR: el árbol publicado no trae todos los paquetes del módulo Go." >&2
  echo "       Un release así no le sirve a ningún servicio (así se retiró tracer.1)." >&2
  exit 1
fi

echo "OK: el árbol publicado trae los ${#PAQUETES[@]} paquetes del módulo Go."