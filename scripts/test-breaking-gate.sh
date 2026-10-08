#!/usr/bin/env bash
# =============================================================================
# scripts/test-breaking-gate.sh — Prueba del propio mecanismo de allowlist (D4).
#
# El mecanismo existe para que las rupturas INTENCIONALES declaradas pasen y
# cualquier otra siga fallando (R5). Una comprobación que no puede fallar no es
# una comprobación: esta prueba ejercita el gate con entradas deterministas y
# afirma el veredicto, en vez de confiar en que "parece correcto".
#
# Casos:
#   1. OpenAPI: una ruptura DECLARADA pasa (exit 0).
#   2. OpenAPI: una ruptura NO declarada falla (exit 1).
#   3. Eventos: una ruptura DECLARADA pasa (exit 0).
#   4. Eventos: una ruptura NO declarada falla (exit 1).
#   5. Versión equivocada: la allowlist de tracer.4 no aplica a otra versión
#      (el gate falla porque no existe rompimientos/<otra>.yaml).
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

GATE_DIR="$RAIZ/tools/breaking-gate"
ROMP="$RAIZ/rompimientos"
VERSION="${VERSION:-$(cat VERSION)}"

gate() { ( cd "$GATE_DIR" && go run . -version "$VERSION" -rompimientos "$ROMP" "$@" ); }

fallos=0
ok()   { echo "    OK: $1"; }
bad()  { echo "    FALLO: $1" >&2; fallos=1; }

# --- Caso 1: OpenAPI, ruptura declarada (catalogos /api/v1/unidades) --------
entrada_openapi_declarada=$'1 changes: 1 error, 0 warning, 0 info\nerror\t[api-path-removed-without-deprecation] at base.yaml\n\tin API GET /api/v1/unidades\n\t\tapi path removed without deprecation'
if echo "$entrada_openapi_declarada" | gate -tipo openapi -servicio catalogos >/dev/null 2>&1; then
  ok "OpenAPI: ruptura declarada pasa"
else
  bad "OpenAPI: una ruptura declarada debería pasar"
fi

# --- Caso 2: OpenAPI, ruptura NO declarada ----------------------------------
entrada_openapi_fantasma=$'1 changes: 1 error, 0 warning, 0 info\nerror\t[api-path-removed-without-deprecation] at base.yaml\n\tin API DELETE /api/v1/clientes/{id}\n\t\tapi path removed without deprecation'
if echo "$entrada_openapi_fantasma" | gate -tipo openapi -servicio catalogos >/dev/null 2>&1; then
  bad "OpenAPI: una ruptura NO declarada no debería pasar"
else
  ok "OpenAPI: ruptura no declarada falla (como debe)"
fi

# --- Caso 3: Eventos, ruptura declarada -------------------------------------
entrada_eventos_declarada='contracts/events/ai27/eventos/v1/viaje.proto:42:1:Previously present field "2" with name "unidad_id" on message "ViajeAsignado" was deleted.'
if echo "$entrada_eventos_declarada" | gate -tipo eventos >/dev/null 2>&1; then
  ok "Eventos: ruptura declarada pasa"
else
  bad "Eventos: una ruptura declarada debería pasar"
fi

# --- Caso 4: Eventos, ruptura NO declarada ----------------------------------
entrada_eventos_fantasma='contracts/events/ai27/eventos/v1/viaje.proto:10:1:Previously present field "5" with name "creado_en" on message "ViajeCreado" was deleted.'
if echo "$entrada_eventos_fantasma" | gate -tipo eventos >/dev/null 2>&1; then
  bad "Eventos: una ruptura NO declarada no debería pasar"
else
  ok "Eventos: ruptura no declarada falla (como debe)"
fi

# --- Caso 5: la allowlist no aplica a otra versión --------------------------
# Con una VERSION distinta, el gate busca rompimientos/<otra>.yaml, que no
# existe, así que la MISMA ruptura declarada para tracer.4 ya no está autorizada.
if echo "$entrada_eventos_declarada" | ( cd "$GATE_DIR" && go run . -tipo eventos -version "v0.1.0-tracer.999" -rompimientos "$ROMP" ) >/dev/null 2>&1; then
  bad "Versión equivocada: la allowlist de tracer.4 no debería autorizar otra versión"
else
  ok "Versión equivocada: la allowlist sólo aplica a su propia versión (como debe)"
fi

echo
if [ "$fallos" -ne 0 ]; then
  echo "ERROR: el mecanismo de allowlist no se comporta como se espera." >&2
  exit 1
fi
echo "OK: el mecanismo de allowlist de rupturas se comporta como se espera."
