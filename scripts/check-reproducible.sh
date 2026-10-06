#!/usr/bin/env bash
# =============================================================================
# scripts/check-reproducible.sh — Codegen reproducible (ADR 25, invariante 6).
#
# "El mismo commit + toolchain producen los mismos checksums." Este script
# comprueba la mitad que se puede comprobar dentro de una corrida: que
# regenerar el commit actual no cambie ningún byte de lo versionado.
#
# Compara contra el COMMIT, no contra el índice ni contra el árbol previo, que es
# lo que lo hace útil como prueba de edición manual:
#
#   - Si alguien edita un *.gen.go a mano y commitea, `make generate` lo
#     sobrescribe y el archivo vuelve a coincidir con la fuente. Un diff contra
#     el árbol de trabajo diría "sin cambios" y el chequeo daría verde sobre un
#     commit con el cliente a mano. Comparar contra HEAD lo detecta.
#   - `make check-arbol-limpio` cubre el caso simétrico: editar a mano y correr
#     el chequeo sin haber commiteado. Sin ese paso previo, la regeneración
#     borraría la prueba.
#
# Los artefactos se commitean (decisión de owner, 2026-10-02, opción (a) del C1
# del handoff tracer.2). Por eso este chequeo tiene efecto: antes, con todo lo
# generado en .gitignore, `git status --porcelain packages/` no veía nada y la
# deriva fuente<->artefacto era invisible.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

# Rutas cuyo contenido es contrato generado.
RUTAS=(packages/api-client-go packages/api-client-ts/src)

fallos=0

# Untracked o eliminados: `git diff` no los ve, `git status` sí.
if [ -n "$(git status --porcelain -- "${RUTAS[@]}")" ]; then
  echo "ERROR: regenerar cambió artefactos generados respecto al commit:"
  git --no-pager diff --stat -- "${RUTAS[@]}"
  echo
  echo "       Si editaste un *.gen.* a mano, revierte el cambio y cambia la"
  echo "       fuente en contracts/. Si no, el codegen no es reproducible con"
  echo "       esta toolchain (ADR 25, invariante 6)."
  fallos=1
fi

# Verificación independiente de la anterior: compara cada artefacto versionado
# contra su blob en HEAD. Distingue "cambió el contenido" de "apareció o
# desapareció un archivo", que `git status --porcelain` reporta igual.
if ! git ls-files -- "${RUTAS[@]}" | while read -r f; do
  [ -n "$f" ] || continue
  if ! git cat-file -e "HEAD:$f" 2>/dev/null; then
    echo "ERROR: artefacto sin versionar (apareció en el árbol): $f"
    exit 1
  fi
  if ! git diff --quiet HEAD -- "$f"; then
    echo "ERROR: artefacto generado que no coincide con la fuente: $f"
    exit 1
  fi
done; then
  fallos=1
fi

if [ "$fallos" -ne 0 ]; then
  exit 1
fi

echo "OK: los artefactos generados coinciden con la fuente (mismo commit + toolchain -> mismos bytes)."