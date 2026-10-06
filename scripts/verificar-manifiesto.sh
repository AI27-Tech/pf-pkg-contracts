#!/usr/bin/env bash
# =============================================================================
# scripts/verificar-manifiesto.sh — Verifica el manifiesto del tracer (ADR 25).
#
# El manifiesto declara checksums de las fuentes y de los artefactos generados.
# Escribirlo es una mitad de la garantía; la otra mitad es comprobar que los
# bytes que promete son los que hay. Sin esta comprobación el manifiesto es un
# documento que nadie contrastó: exactamente el tipo de evidencia decorativa que
# ADR 25 rechaza.
#
# Tres cosas distintas se verifican:
#
#   1. COHERENCIA: todo archivo listado existe y su sha256 coincide. Detecta una
#      edición posterior al freeze.
#
#   2. COMPLETITUD: todo archivo del alcance aparece en el manifiesto. Detecta un
#      artefacto generado que quedó fuera del freeze, que es como un tag puede
#      resolver y aun así no servir a un consumidor.
#
#   3. IDENTIDAD: el tag y el SHA del manifiesto apuntan al commit actual, y la
#      versión coincide con VERSION.
#
# Se usa python3 para el JSON en vez de grep: los checksums están en un array
# JSON y parsearlo es lo correcto. python3 está en las imágenes de CI.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

MANIFESTO="${1:-manifiesto/tracer.manifest.json}"

if [ ! -f "$MANIFESTO" ]; then
  echo "ERROR: no existe $MANIFESTO. Generarlo con: make manifest" >&2
  exit 1
fi

echo "==> Verificando $MANIFESTO contra el árbol de trabajo"

python3 - "$MANIFESTO" <<'PY'
import hashlib, json, os, subprocess, sys

man_path = sys.argv[1]
with open(man_path, encoding="utf-8") as fh:
    man = json.load(fh)

fallos = []

# --- Identidad del freeze -----------------------------------------------------
version = open("VERSION", encoding="utf-8").read().strip()
head = subprocess.run(
    ["git", "rev-parse", "HEAD"], capture_output=True, text=True, check=True
).stdout.strip()

if man.get("version_contractual") != version:
    fallos.append(
        f"version_contractual {man.get('version_contractual')!r} != VERSION {version!r}"
    )
if man.get("tag") != version:
    fallos.append(f"tag {man.get('tag')!r} != VERSION {version!r}")
if man.get("sha") != head:
    fallos.append(f"sha {str(man.get('sha'))[:12]} != HEAD {head[:12]}")

# --- Coherencia: lo listado existe y hashea igual ---------------------------
checks = man.get("checksums", [])
if not checks:
    fallos.append("el manifiesto no lista checksums: no congela nada")

for c in checks:
    path = c.get("archivo", "")
    esperado = c.get("sha256", "")
    if not os.path.isfile(path):
        fallos.append(f"listado en el manifiesto pero no existe: {path}")
        continue
    with open(path, "rb") as fh:
        real = hashlib.sha256(fh.read()).hexdigest()
    if real != esperado:
        fallos.append(f"sha256 distinto: {path}")

# --- Completitud: lo que hay en el alcance está listado ---------------------
# Se recalcula el alcance con la misma selección que scripts/manifiesto.sh.
def fuentes():
    out = subprocess.run(
        ["find", "contracts", "-type", "f",
         "(", "-name", "*.yaml", "-o", "-name", "*.yml", "-o",
         "-name", "*.proto", "-o", "-name", "*.md", ")"],
        capture_output=True, text=True, check=True).stdout.split()
    return sorted(out)

def artefactos_go():
    out = subprocess.run(
        ["find", "packages/api-client-go", "-type", "f", "-name", "*.go"],
        capture_output=True, text=True, check=True).stdout.split()
    return sorted(out)

def artefactos_ts():
    out = subprocess.run(
        ["find", "packages/api-client-ts", "-type", "d", "-name", "node_modules",
         "-prune", "-o", "-type", "f",
         "(", "-name", "*.ts", "-o", "-name", "*.json", ")",
         "!", "-name", "package-lock.json", "-print"],
        capture_output=True, text=True, check=True).stdout.split()
    return sorted(out)

listados = {c.get("archivo") for c in checks}
esperados = {}
for clase, sel in (
    ("fuentes", fuentes),
    ("artefactos_go", artefactos_go),
    ("artefactos_ts", artefactos_ts),
):
    for p in sel():
        esperados[p] = clase

for path, clase in sorted(esperados.items()):
    if path not in listados:
        fallos.append(f"en el alcance ({clase}) pero fuera del manifiesto: {path}")

for path in sorted(listados - set(esperados)):
    fallos.append(f"en el manifiesto pero fuera del alcance: {path}")

# --- Informe ----------------------------------------------------------------
conteo = {}
for c in checks:
    conteo[c.get("clase", "?")] = conteo.get(c.get("clase", "?"), 0) + 1
print(f"    tag={man.get('tag')} sha={str(man.get('sha'))[:12]}")
for clase in sorted(conteo):
    print(f"    {clase}: {conteo[clase]} archivos")

if fallos:
    print()
    for f in fallos:
        print(f"ERROR: {f}")
    print(f"\nERROR: el manifiesto no describe el árbol actual ({len(fallos)} problemas).")
    sys.exit(1)

print("OK: el manifiesto congela exactamente el alcance actual, byte a byte.")
PY
