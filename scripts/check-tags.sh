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

# Uso:
#   check-tags.sh [<ref>] [--verificar-tag-go]
#
# <ref>               commit contra el que se comprueba (el SHA etiquetado en el
#                     job publicar; HEAD si no se indica).
# --verificar-tag-go  además exige que el tag prefijado del módulo Go apunte al
#                     MISMO commit. Sólo tiene sentido en el job publicar, y sólo
#                     justo después de crear ese tag.
#
# Por qué el flag es opt-in: en el job verificar (push a rama, antes de
# publicar) el tag prefijado del release ANTERIOR existe y por definición apunta
# a otro commit. Exigir la igualdad ahí rompe CI en cuanto hay una release
# previa, que es justo el estado normal del repo. La igualdad es una propiedad de
# la publicación, no de cualquier commit.
REF=""
verificar_tag_go=0
for arg in "$@"; do
  case "$arg" in
    --verificar-tag-go) verificar_tag_go=1 ;;
    -*) echo "Opción desconocida: $arg" >&2; exit 2 ;;
    *) REF="$arg" ;;
  esac
done
[ -n "$REF" ] || REF="HEAD"

GO_DIR="packages/api-client-go"

# Paquetes que el módulo Go debe publicar. Los seis clientes HTTP/tipo más el
# sobre común y el registro de tipos de evento.
PAQUETES=(
  identidad
  catalogos
  operacion
  bff
  reportes
  mensajeria
  realtime
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
# contenido no es el congelado: el release y el módulo Go cuentan historias
# distintas.
tag_prefijado="packages/api-client-go/$(cat VERSION)"
if [ "$verificar_tag_go" -eq 1 ]; then
  sha_ref="$(git rev-parse "$REF^{commit}")"
  # Se consulta al ORIGEN: en el job publicar el tag lo acaba de crear el paso
  # anterior empujándolo, y el clon del runner no lo tiene en sus refs locales.
  # Se piden ambas refs (plano y pelado `^{}`) porque `^{}` sólo resuelve tags
  # ANOTADOS; un tag ligero creado fuera de banda no tiene ref pelada y el check
  # lo daba por inexistente (así falló tracer.26). `END{print}` toma la línea
  # pelada cuando existe (anotado, apunta al commit) y la plana si no (ligero).
  sha_tag="$(git ls-remote --tags origin "refs/tags/${tag_prefijado}" "refs/tags/${tag_prefijado}^{}" 2>/dev/null | awk 'END{print $1}')"
  if [ -z "$sha_tag" ]; then
    echo "  FALTA  el tag $tag_prefijado no existe en el origen"
    fallos=1
  elif [ "$sha_tag" != "$sha_ref" ]; then
    echo "  FALTA  el tag $tag_prefijado apunta a ${sha_tag:0:12}, no a ${sha_ref:0:12}"
    fallos=1
  else
    echo "  ok     el tag $tag_prefijado apunta al mismo commit del release"
  fi
fi

if [ "$fallos" -ne 0 ]; then
  echo
  echo "ERROR: el árbol publicado no trae todos los paquetes del módulo Go." >&2
  echo "       Un release así no le sirve a ningún servicio (así se retiró tracer.1)." >&2
  exit 1
fi

echo "OK: el árbol publicado trae los ${#PAQUETES[@]} paquetes del módulo Go."