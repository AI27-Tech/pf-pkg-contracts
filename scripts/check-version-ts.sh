#!/usr/bin/env bash
# =============================================================================
# scripts/check-version-ts.sh — VERSION y package.json del paquete TS coinciden.
#
# La versión del paquete npm es una segunda fuente de verdad, escrita a mano y
# fácil de olvidar al bumpear. Si se queda atrás, el tarball que se publica lleva
# un número distinto al del release, y el consumidor instala algo que no
# corresponde a la release que cree estar instalando. Se comparan entre sí y no
# se derivan: que se avisen mutuamente es lo que las mantiene honestas.
#
# Lo llaman `verificar` (en cada PR, ANTES de que exista el tag) y `publicar`.
# Sólo en `publicar` llegaba tarde: así se perdió el paquete TS de tracer.30 y
# tracer.31, cuyos tags salieron con package.json en 0.1.0-tracer.29.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

version="$(cat VERSION)"
npmver="$(node -p "require('./packages/api-client-ts/package.json').version")"
expected="v${npmver}"
if [ "$version" != "$expected" ]; then
  echo "VERSION dice '$version' pero package.json dice '$npmver'."
  echo "Se bumpean juntas: los artefactos TS se versionan y el manifiesto"
  echo "congela package.json, así que la divergencia llegaría al tag."
  exit 1
fi
echo "OK: VERSION ($version) coincide con package.json ($npmver)."
