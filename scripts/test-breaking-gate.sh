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

# Versión del FIXTURE de esta prueba. Los casos de abajo alimentan rupturas de
# ejemplo tomadas de la allowlist de la ola 1 (tracer.4): el renombre de
# /api/v1/unidades y los campos reservados de ViajeAsignado/ViajeReasignado. La
# prueba ejercita el MECANISMO del gate (declarada pasa, no declarada falla), no
# el contenido de la ola viva, así que fija la versión del fixture y NO hereda
# VERSION del repo. Si heredara VERSION, al abrir una ola nueva (p. ej. tracer.5)
# el gate buscaría rompimientos/<ola nueva>.yaml y estas rupturas de ejemplo
# dejarían de estar declaradas, haciendo fallar la prueba por una razón ajena a
# lo que verifica. El caso 5 usa a propósito OTRA versión para probar justo eso.
VERSION_FIXTURE="v0.1.0-tracer.4"

gate() { ( cd "$GATE_DIR" && go run . -version "$VERSION_FIXTURE" -rompimientos "$ROMP" "$@" ); }
# La allowlist de tracer.45 ejercita el matcher por detalle (línea `in API` + línea
# de detalle de oasdiff). Sus entradas se quedan en el repo, así que el fixture es
# estable aunque VERSION avance.
gate45() { ( cd "$GATE_DIR" && go run . -version "v0.1.0-tracer.45" -rompimientos "$ROMP" "$@" ); }

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
# --- Caso 6: OpenAPI, el detalle acota la ruptura (tracer.45) ---------------
declarada45=$'1 changes: 1 error, 0 warning, 0 info\nerror\t[request-parameter-enum-value-removed] at base.yaml\n\tin API GET /api/v1/viajes\n\t\tremoved the enum value \'SOLICITADO\' from the \'query\' request parameter \'estado\''
if echo "$declarada45" | gate45 -tipo openapi -servicio operacion >/dev/null 2>&1; then
  ok "OpenAPI: el valor de enum retirado y declarado pasa"
else
  bad "OpenAPI: el valor de enum retirado y declarado debería pasar"
fi

# --- Caso 7: otra ruptura en la MISMA ruta no queda autorizada --------------
otra_ruta=$'1 changes: 1 error, 0 warning, 0 info\nerror\t[new-required-request-parameter] at base.yaml\n\tin API GET /api/v1/viajes/{id}\n\t\tadded the new required request parameter X'
if echo "$otra_ruta" | gate45 -tipo openapi -servicio operacion >/dev/null 2>&1; then
  bad "OpenAPI: una ruptura nueva en GET /api/v1/viajes/{id} NO debería pasar con la allowlist de tracer.45"
else
  ok "OpenAPI: una ruptura nueva en una ruta cercana sigue fallando"
fi

# --- Caso 8: otro valor de enum en la misma operación no queda autorizado ---
otro_valor=$'1 changes: 1 error, 0 warning, 0 info\nerror\t[request-parameter-enum-value-removed] at base.yaml\n\tin API GET /api/v1/viajes\n\t\tremoved the enum value \'EN_TRANSITO\' from the \'query\' request parameter \'estado\''
if echo "$otro_valor" | gate45 -tipo openapi -servicio operacion >/dev/null 2>&1; then
  bad "OpenAPI: retirar un valor NO declarado del mismo filtro no debería pasar"
else
  ok "OpenAPI: retirar un valor no declarado del mismo filtro sigue fallando"
fi

# --- Caso 9: `breaking-eventos.sh` compara contra la línea base pedida -------
# Regresión: buf trata `ref=FETCH_HEAD` como HEAD, así que un evento roto pasaba
# en verde porque se comparaba el commit contra sí mismo. El caso reproduce el
# escenario real de CI en un clon temporal: FETCH_HEAD = la base; HEAD = un commit
# que elimina un campo de un evento. Debe FALLAR. Con el comportamiento viejo
# pasaba. Y un ref que no resuelve debe fallar, no compararse contra otra cosa.
if command -v buf >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  git clone -q --no-hardlinks "$RAIZ" "$tmp/r"
  (
    cd "$tmp/r"
    git fetch -q --no-tags origin HEAD            # FETCH_HEAD = la línea base
    cp "$RAIZ/scripts/breaking-eventos.sh" scripts/   # prueba el script de esta copia de trabajo
    python3 - <<'PY'
p = "contracts/events/ai27/eventos/v1/viaje.proto"
s = open(p).read()
a = "message ViajeCreado {\n  string viaje_id = 1;\n  string cliente_id = 2;\n"
assert a in s
open(p, "w").write(s.replace(a, "message ViajeCreado {\n  string viaje_id = 1;\n", 1))
PY
    git -c user.name=t -c user.email=t@t commit -q -am "rompe ViajeCreado"
    if ./scripts/breaking-eventos.sh '.git#ref=FETCH_HEAD' >/dev/null 2>&1; then
      echo "FALLO: un campo eliminado pasó contra ref=FETCH_HEAD (comparó HEAD contra HEAD)" >&2
      exit 1
    fi
    if ./scripts/breaking-eventos.sh '.git#ref=no-existe-este-ref' >/dev/null 2>&1; then
      echo "FALLO: un ref que no resuelve debería fallar, no omitirse" >&2
      exit 1
    fi
  ) && ok "Eventos: el chequeo compara contra la línea base pedida (FETCH_HEAD) y no contra HEAD" \
    || bad "Eventos: el chequeo no compara contra la línea base pedida"
  rm -rf "$tmp"
else
  echo "    (omitido: buf no está instalado)"
fi

if [ "$fallos" -ne 0 ]; then
  echo "ERROR: el mecanismo de allowlist no se comporta como se espera." >&2
  exit 1
fi
echo "OK: el mecanismo de allowlist de rupturas se comporta como se espera."
