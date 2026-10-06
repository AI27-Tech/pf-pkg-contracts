#!/usr/bin/env bash
# =============================================================================
# scripts/check-ts-exports.sh — El paquete npm sirve lo que dice servir (C2).
#
# `exports` es una promesa: si declara un subpath que no resuelve, el consumidor
# no recibe un error de contrato sino un MODULE_NOT_FOUND en su propio build, sin
# ninguna relación con este repositorio. El typecheck del paquete (tsc --noEmit
# sobre src/) no lo detecta, porque nunca resuelve los subpaths: mira los
# archivos por ruta relativa.
#
# La forma correcta de probar un `exports` es empacar el tarball e instalarlo en
# un proyecto limpio, y luego resolver cada subpath publicado. Eso es lo que hace
# este script, y lo hace sobre el tarball que `npm publish` enviaría, no sobre el
# árbol de trabajo.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="$RAIZ/packages/api-client-ts"

cd "$PKG"

VERSION="$(node -p "require('./package.json').version")"
echo "==> Comprobando los 'exports' de @ai27-tech/contracts@${VERSION}"

# npm pack respeta `files` y los campos que el registry va a usar: el tarball
# que sale de aquí es el que se publica.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

TARBALL="$(npm pack --pack-destination "$TMP" --silent | tail -1)"
[ -f "$TMP/$TARBALL" ] || { echo "ERROR: npm pack no produjo $TARBALL" >&2; exit 1; }

# Subpaths declarados en exports, leídos del propio package.json. Se derivan en
# vez de hardcodearse: si exports crece, la prueba crece con él.
SUBPATHS="$(node -e "
const ex = require('./package.json').exports;
const out = [];
for (const [k, v] of Object.entries(ex)) {
  if (k === '.') { out.push('@ai27-tech/contracts'); continue; }
  if (!k.includes('*')) { out.push('@ai27-tech/contracts' + k.slice(1)); continue; }
  // Un patrón sólo se puede probar con una entrada real: se toma el primer
  // ARCHIVO (en profundidad) que exista bajo el prefijo del patrón. Con
  // directorios intermedios —eventos/ai27/eventos/v1— el primer hijo suele ser
  // un directorio, y probar '.../ai27/index' daría un falso negativo.
  const path = require('path');
  const fs = require('fs');
  const prefijo = k.slice(2, k.indexOf('*')).replace(/\/+$/, ''); // p.ej. openapi
  const raiz = path.join(process.cwd(), 'src', prefijo);
  const primerArchivo = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      if (e.isFile() && /\.(ts|js)$/.test(e.name)) return path.join(dir, e.name);
      if (e.isDirectory()) {
        const r = primerArchivo(path.join(dir, e.name));
        if (r) return r;
      }
    }
    return null;
  };
  const archivo = primerArchivo(raiz);
  if (!archivo) { out.push('# sin archivos bajo src/' + prefijo); continue; }
  // Se quita la extensión que el patrón reescribe (los archivos reales llevan
  // .gen.ts; el patrón los reescribe a .ts o se los añade).
  const rel = path.relative(path.join(process.cwd(), 'src'), archivo).replace(/\.(gen\.)?(ts|js)$/, '');
  out.push('@ai27-tech/contracts/' + rel);
}
console.log(out.join('\n'));
")"

if [ -z "$SUBPATHS" ] || echo "$SUBPATHS" | grep -q '^#'; then
  echo "ERROR: no se pudieron derivar los subpath a probar:" >&2
  echo "$SUBPATHS" >&2
  exit 1
fi

echo "$SUBPATHS" | sed 's/^/    /'

# Instalación limpia: sin node_modules del repo, sin tsconfig, sin rutas relativas.
mkdir -p "$TMP/consumidor"
(
  cd "$TMP/consumidor"
  npm init -y >/dev/null 2>&1
  npm install --silent "$TMP/$TARBALL" >/dev/null 2>&1
  node -e "
const subs = process.argv.slice(1);
const fallos = [];
for (const s of subs) {
  try { require.resolve(s); }
  catch (e) { fallos.push(s + ' (' + e.code + ')'); }
}
if (fallos.length) {
  console.error('    ERROR: subpath declarado en exports que no resuelve:');
  for (const f of fallos) console.error('      - ' + f);
  process.exit(1);
}
console.log('    OK: ' + subs.length + ' subpath(s) resuelven desde el tarball publicado.');
" $SUBPATHS
)

echo "OK: el paquete npm sirve todos los subpath que declara."
