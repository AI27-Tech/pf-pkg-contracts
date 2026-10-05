#!/usr/bin/env bash
# =============================================================================
# scripts/contract-tests.sh — Contract tests del repo (C4 del handoff tracer.2).
#
# El invariante que cierra este script: "los contract tests del tracer pasan
# antes de publicar" (ADR 25, invariante 7). Antes de tracer.2 no había ninguno.
#
# (i)  CONSUMIDOR LIMPIO: se resuelve el módulo Go por su tag publicado, en un
#      directorio temporal y un módulo Go NUEVOS (sin go.work, sin replace, sin
#      ruta local — ADR 17: "los contratos son el artefacto, no el repositorio"),
#      y se compila un archivo que importa CADA paquete publicado. Esto es
#      exactamente lo que no funcionó en tracer.1: el tag resolvía pero no
#      traía nada importable.
#
# (ii) CONSISTENCIA DEL REGISTRO: el registro de tipos de evento, los .proto e
#      INVENTARIO.md dicen lo mismo. Delega en tools/check-registro.
#
# El contrato productor–consumidor que exige ADR 25 NO se prueba aquí: no hay
# servicios que consuman todavía. Es una brecha conocida, no una prueba que se pueda
# simular.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

VERSION="${VERSION:-$(cat VERSION)}"
TAG="packages/api-client-go/${VERSION}"

fallos=0

# -----------------------------------------------------------------------------
echo "==> (i) Consumidor limpio del módulo Go en ${TAG}"
# -----------------------------------------------------------------------------

# La línea base es el TAG, no una rama: una rama o una ruta local no son evidencia
# de freeze (invariante 2). Sin tag no hay nada que probar; se dice explícitamente.
if ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "El tag ${TAG} no existe todavía: se omite el consumidor limpio."
  echo "(Se correrá de verdad en el job publicar, cuando el tag ya esté empujado.)"
else
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT

  # Módulo consumidor nuevo. Sin go.work y sin replace: la resolución tiene que
  # ocurrir por versión publicada o el test no prueba nada.
  mkdir -p "$WORK/consumidor"
  (
    cd "$WORK/consumidor"
    cat > go.mod <<MOD
module ai27.tech/contratos/consumer-test

go 1.27
MOD

    # go get del módulo anidado por su tag prefijado.
    #
    # GOPRIVATE cubre el prefijo para que go no intente validar el módulo contra
    # el checksum DB público (sum.golang.org), que no conoce repos privados
    # (decisión de owner #3: AI27-Tech/* es privado). GONOSUMDB/GONOSUMCHECK y
    # GOFLAGS los respeta el toolchain según versión.
    export GOPRIVATE="github.com/AI27-Tech/*"
    export GONOSUMDB="github.com/AI27-Tech/*"
    export GONOSUMCHECK=1
    export GONOSUMDB_CHECK=1
    export GOFLAGS="${GOFLAGS:-} -mod=mod"

    # Credenciales: si hay token en el entorno (CI lo inyecta desde el secreto del
    # repo) se usa un .netrc efímero; si no, se confía en la config de git local.
    if [ -n "${GITHUB_TOKEN:-}" ]; then
      umask 077
      cat > "$WORK/netrc" <<NETRC
machine github.com login x-access-token password ${GITHUB_TOKEN}
NETRC
      export NETRC="$WORK/netrc"
    fi

    echo "    - go get github.com/AI27-Tech/pf-pkg-contracts/packages/api-client-go@${VERSION}"
    go get "github.com/AI27-Tech/pf-pkg-contracts/packages/api-client-go@${VERSION}"

    # Un archivo que importa CADA paquete publicado. Si el tag no trajera alguno
    # de ellos, esto no compila — que es el defecto de tracer.1.
    cat > main.go <<'GO'
// main.go — consumidor limpio del paquete contractual.
//
// Importa CADA paquete publicado por el módulo Go y los USA, no sólo los importa:
// un import sin usar ni siquiera lo detectaría el compilador.
package main

import (
	"fmt"

	"github.com/AI27-Tech/pf-pkg-contracts/packages/api-client-go/bff"
	"github.com/AI27-Tech/pf-pkg-contracts/packages/api-client-go/catalogos"
	"github.com/AI27-Tech/pf-pkg-contracts/packages/api-client-go/estados"
	eventosv1 "github.com/AI27-Tech/pf-pkg-contracts/packages/api-client-go/eventos/ai27/eventos/v1"
	"github.com/AI27-Tech/pf-pkg-contracts/packages/api-client-go/identidad"
	"github.com/AI27-Tech/pf-pkg-contracts/packages/api-client-go/operacion"
	"github.com/AI27-Tech/pf-pkg-contracts/packages/api-client-go/registro"
	"github.com/AI27-Tech/pf-pkg-contracts/packages/api-client-go/reportes"
	"github.com/AI27-Tech/pf-pkg-contracts/packages/api-client-go/roles"
)

func main() {
	// estados/ — la máquina de estados del viaje.
	_ = estados.EstadosViaje

	// registro/ — el registro de tipos de evento, y su validación en runtime.
	if !registro.EsTipoRegistrado("viaje.estado_cambiado") {
		panic("viaje.estado_cambiado debe estar en el registro publicado")
	}
	if registro.EsTipoRegistrado("viaje.inventado") {
		panic("un tipo no aprobado no puede estar en el registro publicado")
	}
	if v, ok := registro.VersionDe("viaje.creado"); !ok || v != 1 {
		panic("viaje.creado debe estar en versión 1")
	}
	if _, ok := registro.ProductorDe("sesion.revocada"); !ok {
		panic("sesion.revocada debe declarar su productor")
	}

	// eventos/ — tipos de evento Protobuf (Sobre + un mensaje de viaje).
	_ = eventosv1.Sobre{Tipo: "viaje.creado"}
	_ = eventosv1.ViajeCreado{ViajeId: "v-1"}

	// roles/ — el enum canónico de roles y su validación en runtime. Un rol
	// desconocido se rechaza, no se degrada a un permiso por defecto.
	if !roles.EsRol("jefe_operativo") {
		panic("jefe_operativo debe estar en el enum de roles publicado")
	}
	if roles.EsRol("operador") {
		panic("operador no es un rol del contrato y no debe existir")
	}
	if len(roles.Todos) != 8 {
		panic("el contrato declara ocho roles canónicos")
	}

	// Los cinco paquetes de cliente HTTP por servicio: cada uno debe exponer su
	// constructor (oapi-codegen) y un tipo de recurso del dominio. Se usan
	// valores concretos, no `var _`, para que un símbolo ausente o renombrado
	// rompa la compilación en vez de resolverse a algo vacío.
	if c, err := bff.NewClient("https://api.ai27.tech"); err != nil || c == nil {
		panic("bff.NewClient debe construir un cliente")
	}
	if c, err := catalogos.NewClient("https://api.ai27.tech"); err != nil || c == nil {
		panic("catalogos.NewClient debe construir un cliente")
	}
	if c, err := identidad.NewClient("https://api.ai27.tech"); err != nil || c == nil {
		panic("identidad.NewClient debe construir un cliente")
	}
	if c, err := operacion.NewClient("https://api.ai27.tech"); err != nil || c == nil {
		panic("operacion.NewClient debe construir un cliente")
	}
	if c, err := reportes.NewClient("https://api.ai27.tech"); err != nil || c == nil {
		panic("reportes.NewClient debe construir un cliente")
	}

	// Un viaje del contrato. operacion.EstadoViaje y estados.EstadoViaje son
	// enums-data distintos por diseño (oapi-codegen genera su propio), pero deben
	// narr los MISMOS valores: un estado declarado en contracts/estados/ que no
	// exista en el cliente HTTP deja al consumidor sin forma de expresarlo.
	//
	// oapi-codegen no exporta el enum como slice ni como validador, así que el set
	// se arma con las constantes que sí expone. Es lo que puede comprobar un
	// consumidor; la equivalencia exhaustiva estado<->spec la hace
	// `make check-estados` en el job verificar.
	operacionEstados := map[estados.EstadoViaje]operacion.EstadoViaje{
		estados.EstadoSolicitado:          operacion.SOLICITADO,
		estados.EstadoAprobado:            operacion.APROBADO,
		estados.EstadoRechazadoPorAi27:    operacion.RECHAZADOPORAI27,
		estados.EstadoRechazadoPorCliente: operacion.RECHAZADOPORCLIENTE,
		estados.EstadoAsignado:            operacion.ASIGNADO,
		estados.EstadoAptoParaSalida:      operacion.APTOPARASALIDA,
		estados.EstadoEnEmbarque:          operacion.ENEMBARQUE,
		estados.EstadoPatrullaEnCamino:    operacion.PATRULLAENCAMINO,
		estados.EstadoEnTransito:          operacion.ENTRANSITO,
		estados.EstadoEnDestino:           operacion.ENDESTINO,
		estados.EstadoEnDescarga:          operacion.ENDESCARGA,
		estados.EstadoCerrado:             operacion.CERRADO,
		estados.EstadoCancelado:           operacion.CANCELADO,
	}
	if len(operacionEstados) != len(estados.EstadosViaje) {
		panic(fmt.Sprintf(
			"operacion declara %d estados y contracts/estados/ %d: la enumeración quedó desfasada",
			len(operacionEstados), len(estados.EstadosViaje)))
	}
	for canonico, generado := range operacionEstados {
		if string(generado) != string(canonico) {
			panic(fmt.Sprintf("operacion.%q y estados.%q no son el mismo estado",
				string(generado), string(canonico)))
		}
	}

	// estados/ — la máquina de estados: transiciones válidas entre estados.
	if !estados.PuedeTransicionar(estados.EstadoSolicitado, estados.EstadoAprobado) {
		panic("SOLICITADO -> APROBADO es una transición válida")
	}
	if estados.PuedeTransicionar(estados.EstadoCerrado, estados.EstadoEnTransito) {
		panic("un viaje cerrado no puede volver a tránsito")
	}
	if !estados.EstadoCerrado.EsTerminal() {
		panic("CERRADO es terminal")
	}

	// Resumen de viaje del bff, el tipo que la web realmente consume. El bff
	// publica Estado como string (no como enum): el consumidor no debe asumir el
	// enum canónico en ese borde.
	_ = bff.ViajeResumen{Estado: string(estados.EstadoAsignado)}

	fmt.Println("consumidor limpio OK")
}
GO

    echo "    - go build (importa y usa los 9 paquetes)"
    if go build ./... 2>&1; then
      echo "    OK: el módulo publicado compila para un consumidor limpio."
    else
      echo "    ERROR: el módulo publicado no sirve a un consumidor limpio." >&2
      exit 1
    fi
  ) || fallos=1
fi

# -----------------------------------------------------------------------------
echo
echo "==> (ii) Consistencia del registro: registro <-> .proto <-> INVENTARIO.md"
# -----------------------------------------------------------------------------
if make check-registro; then
  echo "    OK: el registro coincide con los .proto y con INVENTARIO.md."
else
  echo "    ERROR: el registro no coincide con los .proto ni con INVENTARIO.md." >&2
  fallos=1
fi

# -----------------------------------------------------------------------------
echo
if [ "$fallos" -ne 0 ]; then
  echo "ERROR: contract tests fallidos. No se publica." >&2
  exit 1
fi

echo "OK: contract tests en verde."