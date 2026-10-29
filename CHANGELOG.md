# Changelog — pf-pkg-contracts

Registro de cambios del repositorio. El formato y las reglas están definidos en
`.kiro/steering/changelog.md`. Entradas en español, las más recientes primero.

## 2026-10-29 [tracer.22] — lectura de incidencias del viaje (E8-T13 / DEC-110)

**Resumen:** Ola aditiva que cierra la última pieza del histórico operativo del panel interno: la **lectura** de incidencias. Agrega `listarIncidencias` = `GET /api/v1/viajes/{id}/incidencias` en `operacion` y su espejo de reenvío en `bff`, más el esquema `PaginaIncidencias` en ambos. Espejo exacto de `listarEstadias`/`listarBitacora`: paginación por `cursor`, respuestas `200 PaginaIncidencias` / `401` / `404`. El esquema `Incidencia` no cambia.

**Contexto:** Solicitud de `pf-web-frontend-internal` (E8-T13, DEC-110), verificada contra `tracer.21`. En `.21` el histórico quedó con abrir/resolver incidencia pero sin lectura: el frontend podía mostrar incidencias abiertas/resueltas en la sesión viva, pero al recargar el histórico de incidencias previas quedaba invisible. DEC-105 proyectó siete operaciones del histórico pero no incluyó la lectura de incidencias; DEC-110 la autoriza. A diferencia de lo que suponía el brief, `operacion` **no** exponía `listarIncidencias`: hubo que agregarla ahí primero, porque el `bff` es reenvío puro (DEC-105 §1).

**Decisión de forma (DEC-110):** `operationId` idéntico en `operacion` y `bff` (`listarIncidencias`), patrón DEC-105 §2. Paginación por `cursor` por consistencia con bitácora/estadías. Respuestas `200/401/404`, iguales a `listarEstadias`/`listarBitacora` del `bff` (sin `403` por paridad con los otros dos espejos de lectura del histórico). `tipo_interno` sigue `string` crudo (audiencia interna, DEC-105 §5); el curado al cliente (DEC-006) queda fuera de esta superficie. El histórico es append-only: la lista incluye incidencias `en_atencion` y `resuelta`. No se agrega ningún campo a `Incidencia`.

**Cambios:**
- `contracts/openapi/operacion.yaml`: ruta `GET /api/v1/viajes/{id}/incidencias` (`listarIncidencias`); esquema `PaginaIncidencias`.
- `contracts/openapi/bff.yaml`: ruta espejo `GET /api/v1/viajes/{id}/incidencias` (`listarIncidencias`, reenvía a `operacion`); esquema espejo `PaginaIncidencias`.
- Clientes Go y TS regenerados (`make generate`). `VERSION`, los ocho specs y `_comunes.yaml`, el paquete TS y el encabezado de `INVENTARIO.md` a `0.1.0-tracer.22`.

**Compatibilidad:** aditivo. `make breaking-openapi` confirma los ocho specs compatibles con `tracer.21` (solo se agregó un `GET` y un esquema; nada se estrechó ni se quitó). Sin entrada en `rompimientos/`. `lint-openapi` y `breaking-openapi` en verde; clientes Go compilan y pasan `go vet`.

**Archivos modificados:**
- `contracts/openapi/operacion.yaml`, `contracts/openapi/bff.yaml`, los otros seis specs y `_comunes.yaml` (solo `info.version`), `VERSION`, `contracts/events/INVENTARIO.md` (encabezado de ola)
- `packages/api-client-go/{operacion,bff}/*.gen.go`, `packages/api-client-ts/src/openapi/{operacion,bff}.gen.ts`, `packages/api-client-ts/package.json`
- `CHANGELOG.md`

## 2026-10-23 [tracer.21] — ficha técnica del viaje (E8-T12) e histórico operativo en el `bff` (E8-T13)

**Resumen:** Ola aditiva que combina dos solicitudes del panel interno. (1) **E8-T12 / DEC-104:** la ficha técnica del viaje gana lectura y escritura parcial. En `operacion`: ruta `GET|PATCH /api/v1/viajes/{id}/ficha` (`obtenerFicha`/`guardarFicha`), esquemas `FichaTecnica`/`FichaTecnicaEntrada`/`Tracto`/`Contenedor`; `tipo_servicio` ahora se lee en `Viaje` (solo lectura); `tracto` se captura en `CrearViajeEntrada`; `Destino` gana `arribo`. En `catalogos`: catálogo de GPS nuevo `GET /api/v1/gps` (`listarGps`→`PaginaGps`/`DispositivoGps`). Todo proyectado al `bff`. (2) **E8-T13 / DEC-105:** siete reenvíos del histórico al `bff` (bitácora, incidencias, estadías), espejo de operaciones que ya existían en `operacion`.

**Contexto:** Dos solicitudes de `pf-web-frontend-internal` (E8-T12 ficha técnica, E8-T13 histórico), decididas en DEC-104 y DEC-105. Se publican en una sola ola porque no se solapan (tocan zonas distintas de `bff.yaml`, sin colisión de nombres) y ambas estaban cerradas. Ambas DEC apuntaban al "siguiente tracer libre tras `.20`": es `tracer.21`.

**E8-T12 (ficha, DEC-104):** el tracto pasa a objeto `{placas, economico, marca, modelo, color}` (texto libre, opcional) porque Operación buscará por placa/económico — supera el "texto libre" de DEC-011 #2; como el cliente también lo captura, entra además en `CrearViajeEntrada`. Contenedores `0..N` con los campos del sistema actual (`economico/placas/sello/color`). La ficha es editable e incremental (DEC-043 #3): el PATCH no exige ningún campo y en V1 ningún campo de ficha gatea transiciones de estado. La escolta NO se recaptura: se deriva de la asignación (DEC-044). `tipo_servicio` es solo lectura (valores de catálogo aún pendientes, por eso `string` y no enum). GPS como referencia al catálogo registrado, sin posición en vivo (DEC-012/047); el selector recibe solo dispositivos activos (filtro en servidor); no se gatea exclusividad de GPS por viaje.

**E8-T13 (histórico, DEC-105):** siete reenvíos con guardas de alcance/rol del `bff`, sin lógica de dominio, `operationId` idénticos a `operacion`: `listarBitacora`, `registrarEntradaBitacora`, `abrirIncidencia` (`409 condicion_ya_abierta`), `resolverIncidencia`, `listarEstadias`, `abrirEstadia`, `cerrarEstadia` (`409 estadia_ya_cerrada`). `operacion.yaml` no cambia para esto (las siete ya existían). `tipo_interno` de incidencia se mantiene `string` (sin enum aún; se tipificará cuando Operación entregue el catálogo). Se preserva el curado al cliente fuera del contrato interno (DEC-006) y la duración de estadía derivada sin `prolongada` (DEC-038).

**Cambios:**
- `contracts/openapi/operacion.yaml`: ruta `GET|PATCH /api/v1/viajes/{id}/ficha`; esquemas `FichaTecnica`, `FichaTecnicaEntrada`, `Tracto`, `Contenedor`; `Viaje.tipo_servicio` (lectura, `nullable`); `CrearViajeEntrada.tracto`; `Destino.arribo`.
- `contracts/openapi/catalogos.yaml`: ruta `GET /api/v1/gps` (`listarGps`); esquemas `DispositivoGps`, `PaginaGps`.
- `contracts/openapi/bff.yaml`: rutas espejo `GET|PATCH /viajes/{id}/ficha`, `GET /gps`, y las 7 del histórico (`/bitacora`, `/incidencias`, `/incidencias/{iid}`, `/estadias`, `/estadias/{eid}`); esquemas espejo de ficha, GPS y todo el histórico; `ViajeInterno` gana `tipo_servicio` y `arribo` en el destino embebido.
- Clientes Go y TS regenerados (`make generate`). `VERSION`, los ocho specs, el paquete TS y el encabezado de `INVENTARIO.md` a `0.1.0-tracer.21`.

**Compatibilidad:** aditivo. `make breaking-openapi` confirma los ocho specs compatibles con `tracer.20`. Todos los campos nuevos son opcionales o rutas/esquemas de adición. Sin entrada en `rompimientos/`. `lint-openapi`, `verify` (incl. `check-estados` 13 estados), `breaking-openapi` y `check-ts-exports` en verde; clientes Go compilan y pasan `go vet`.

**Archivos modificados:**
- `contracts/openapi/operacion.yaml`, `contracts/openapi/catalogos.yaml`, `contracts/openapi/bff.yaml`, los otros cinco specs y `_comunes.yaml` (solo `info.version`), `VERSION`, `contracts/events/INVENTARIO.md` (encabezado de ola)
- `packages/api-client-go/{operacion,catalogos,bff}/*.gen.go`, `packages/api-client-ts/src/openapi/{operacion,catalogos,bff}.gen.ts`, `packages/api-client-ts/package.json`
- `CHANGELOG.md`

## 2026-10-26 [tracer.20] — brechas de E8-T11 y E8-T5: selector de cliente, `estado` en `Asignacion`, y segundo factor en el login del `bff` (E1-HU-028, E1-HU-004, E4-HU-017)

**Resumen:** Tres adiciones al `bff` (una con espejo en `operacion`) que desbloquean dos tareas del panel interno, todas aditivas. (1) E8-T11: `GET /api/v1/clientes` → `listarClientes`, proyección de `catalogos.listarClientes` para poblar el selector de cliente al crear un viaje por Operación. (2) E8-T11: `Asignacion` gana `estado` (token de `EstadoViaje`) para afirmar `ASIGNADO` tras asignar sin que el consumidor lo infiera; se agrega en `operacion` y se proyecta al `bff` (espejo completo). (3) E8-T5: `CredencialesEntrada` del `bff` gana `segundo_factor` (TOTP), proyección del campo que ya existía en `identidad`.

**Contexto:** Dos solicitudes de `pf-web-frontend-internal` (E8-T11 el 2026-10-23, E8-T5 el 2026-10-26). Todas las decisiones de diseño están en DEC-101. Esta ola **re-aplica** el contenido que se publicó como `tracer.19` (PR #70), se revirtió (PR #72) para dejar entrar primero el fix de `refrescarSesion` (que tomó `tracer.19`), y se reintroduce sin cambios de forma salvo el número de ola.

Brecha 1 (clientes): el maestro ya vive en `catalogos` (`listarClientes`/`Cliente`/`PaginaClientes`), pero la regla de puerta única impide al frontend llamarlo directo. Se proyecta al `bff` como reenvío, mismo patrón que `listarUnidades`→`operacion` (tracer.18). Paginado por cursor; NO se proyecta el parámetro `ids` de `catalogos` (es la lectura por lote de `mensajeria`). DEC-026 #3 exige limitar la lista al alcance del `jefe_operativo` y DEC-101 añade que el `bff` devuelve SOLO clientes `activo`: ambos filtros los resuelve el servidor, no el frontend ni el schema; la forma del contrato no cambia (`PaginaClientes`/`Cliente`, espejo exacto de `catalogos`).

Brecha 2 (`estado` en `Asignacion`): `Asignacion` era el único miembro de la familia sin `estado`, cuando `ViajeResumen`/`ViajeInterno` ya lo traen. Se agrega como requerido en `operacion.Asignacion` (referencia al enum `EstadoViaje`) y se proyecta al `bff` como `string` token (el `bff` no replica el enum, igual que los otros schemas). Espejo completo sobre solo-`bff` para no crear la incoherencia "el `bff` afirma una forma que el dominio no tiene". Corrección registrada: la respuesta de `asignarRecursos` es `200`, no `201`.

Brecha 3 (segundo factor): `identidad.CredencialesEntrada.segundo_factor` ya existe (TOTP, `nullable`, opcional V1); el `bff` no lo tenía y su `additionalProperties: false` impedía enviarlo. Proyección pura, misma forma y semántica: el IdP (Keycloak) valida, el `bff` transporta (DEC-031/DEC-071). El `codigo` estable que distinguiría "segundo factor inválido" de "credenciales inválidas" en el 401 queda ABIERTO, delegado a identidad/Keycloak (DEC-101 #5): no se define un código que el IdP quizá no pueda emitir. No bloquea E8-T5 (el campo basta para capturar y enviar el TOTP).

Número de ola: `tracer.19` la tomó el fix de `refrescarSesion` (que entró a `-d` antes y revirtió esta ola), así que esta re-aplicación toma el siguiente libre, `tracer.20` (regla de versión §7; mismo caso de "la que no tagueó primero se corre"). `tracer.19` no estaba tagueado al momento de re-aplicar.

**Cambios:**
- `contracts/openapi/bff.yaml`: ruta `GET /api/v1/clientes` (`listarClientes` → `PaginaClientes`; 401/403); esquemas nuevos `Cliente`/`PaginaClientes` espejo de `catalogos`; `Asignacion.estado` (token `string`, requerido); `CredencialesEntrada.segundo_factor` (TOTP, `nullable`).
- `contracts/openapi/operacion.yaml`: `Asignacion.estado` (referencia a `EstadoViaje`, requerido).
- Clientes Go y TS regenerados (`make generate`): `bff.gen.go/ts`, `operacion.gen.go/ts`. `VERSION`, los ocho specs, el paquete TS y el encabezado de `INVENTARIO.md` a `0.1.0-tracer.20`.

**Compatibilidad:** aditivo. `make breaking-openapi` confirma los ocho specs compatibles con `tracer.19` (`bff` y `operacion` "cambió, compatible"; el resto solo bump de versión). `segundo_factor` es opcional/`nullable`; `Asignacion.estado` y la ruta de clientes son adiciones. Sin entrada en `rompimientos/`. `make lint-openapi`, `check-estados` y `check-registro` en verde; clientes Go compilan y pasan `go vet`.

**Archivos modificados:**
- `contracts/openapi/bff.yaml`, `contracts/openapi/operacion.yaml`, los otros seis specs y `_comunes.yaml` (solo `info.version`), `VERSION`, `contracts/events/INVENTARIO.md` (encabezado de ola)
- `packages/api-client-go/bff/bff.gen.go`, `packages/api-client-go/operacion/operacion.gen.go`, `packages/api-client-ts/src/openapi/bff.gen.ts`, `packages/api-client-ts/src/openapi/operacion.gen.ts`, `packages/api-client-ts/package.json`
- `CHANGELOG.md`

## 2026-10-23 [tracer.19] — `refrescarSesion` declarada pública en el contrato (alinea contrato con runtime)

**Resumen:** Se añade `security: []` a `refrescarSesion` en `identidad.yaml`, igual que ya lo tenía `emitirSesion`. Hasta ahora `refrescarSesion` heredaba el `security` global (`bearerCognito`), así que el contrato la declaraba protegida; pero el servidor de `pf-svc-identidad` la monta SIN middleware de auth (es pública, como `emitirSesion`), porque el refresh usa el refresh token del cuerpo, no un access token válido en el header. El contrato y el runtime se contradecían; esta ola los alinea.

**Contexto:** La brecha se detectó al unificar el passthrough del token en el `bff` (`pf-svc-bff` PR #29): al decidir qué aristas propagan el Bearer, se verificó contra el servidor que `refrescarSesion` es pública en runtime (`identidad.go`: `mux.HandleFunc` sin `protegido`) y que el contrato no lo reflejaba. El riesgo del desajuste es un consumidor generado desde el contrato que exija un `Authorization` para refrescar, justo cuando el access token suele estar vencido. ADR 26 trata el refresh como el punto de reevaluación de claims a partir del refresh token, no del access token.

Número de ola: `tracer.18` (proyección de asignación/roster al `bff`) es la última publicada en `-d`; no hay `19` tomada por tag ni por rama (verificado contra tags, `VERSION` y PRs abiertos), así que toma el siguiente libre, `tracer.19` (regla de versión de contratos §7).

**Cambios:**
- `contracts/openapi/identidad.yaml`: `refrescarSesion` gana `security: []` con comentario de por qué es pública. Ningún otro cambio de forma: rutas, parámetros, cuerpos y respuestas idénticos.
- `VERSION`, los ocho specs OpenAPI (`info.version`) y el encabezado de `INVENTARIO.md` a `0.1.0-tracer.19`.

**Compatibilidad:** aditivo/relajante. `breaking-openapi` confirma compatible con `tracer.18` (relajar `security` no rompe a ningún consumidor). Los tipos Go/TS generados NO cambian: `security` es metadata de la operación, no genera código; `check-reproducible` confirma que los artefactos generados coinciden byte a byte. `check-tags`, `check-registro` y `contract-tests` en verde.

**Archivos modificados:**
- `contracts/openapi/identidad.yaml` y los otros siete specs + `_comunes.yaml` (solo `info.version`), `VERSION`, `contracts/events/INVENTARIO.md` (encabezado de ola)
- `packages/api-client-ts/package.json` (`version`)
- `CHANGELOG.md`

## 2026-10-22 [tracer.18] — proyectar asignación de escolta y roster de unidades al `bff` (E8-T10, E1-HU-004)

**Resumen:** Se proyectan al `bff` dos capacidades que ya existían en `operacion` y no estaban expuestas por la puerta única del frontend: asignar la escolta a un viaje (`POST /api/v1/viajes/{id}/asignacion` → `asignarRecursos`) y listar el roster de unidades (`GET /api/v1/unidades` → `listarUnidades`). Es una proyección espejo: mismos verbos, rutas y esquemas que `operacion`, reenviados por el `bff` con sus guardas de alcance/rol, sin lógica de dominio nueva.

**Contexto:** La brecha la reportó `pf-web-frontend-internal` desde E8-T10 (satisface `E1-HU-004`), que hoy opera contra mocks. El frontend consume sólo el contrato del `bff` (regla de puerta única); `asignarRecursos`/`listarUnidades` existían en `operacion` desde olas previas pero no estaban proyectadas, así que el frontend no podía usarlas contra backend real. La reserva atómica (o todas las unidades o ninguna), la transición `APROBADO → ASIGNADO` (DEC-026) y la aptitud informativa que no gatea (DEC-055, ADR 31) viven en `operacion`; el `bff` sólo reenvía.

Dos decisiones cerradas con el consumidor antes de publicar: (1) la respuesta de asignar es `Asignacion { viaje_id, unidades: UnidadAsignada[] }` —proyección fiel, con aptitud informativa por átomo—, no `ViajeDetalle`; el frontend refresca el viaje invalidando la query del detalle (segundo GET barato), no pidiendo recomposición al `bff`. (2) el 409 de asignar usa el único código de rechazo del dominio, `recurso_no_disponible`, que incluye la carrera contra otro jefe operativo; el dominio NO distingue "en conflicto" de "sin disponibles" (la distinción fina se escaló a Operación como propuesta aparte, no bloquea E8-T10). Se conserva el nombre espejo `asignarRecursos` (no `asignarEscolta`) por la convención de proyección del `bff`. Reasignar (`reasignarRecursos`, PATCH) queda fuera de alcance: no lo necesita E8-T10.

Número de ola: `tracer.17` (familia de emergencia, E7) es la última publicada en `-d`; no hay ola `18` tomada por tag ni por rama (verificado contra tags y `VERSION`), así que toma el siguiente libre, `tracer.18` (regla de versión de contratos §7).

**Cambios:**
- `contracts/openapi/bff.yaml`: rutas `POST /api/v1/viajes/{id}/asignacion` (`asignarRecursos` → `Asignacion`; 400/401/403; 409 con `codigo` `recurso_no_disponible`) y `GET /api/v1/unidades` (`listarUnidades` → `PaginaUnidades`; 401/403). Esquemas nuevos espejo de `operacion`: `AsignacionEntrada`, `Asignacion`, `UnidadAsignada`, `AptitudRecurso`, `Unidad`, `PaginaUnidades`.
- Clientes Go y TS regenerados (`make generate`). `VERSION`, los ocho specs OpenAPI y el encabezado de `INVENTARIO.md` a `0.1.0-tracer.18`.

**Compatibilidad:** aditivo. `make breaking-openapi` confirma los ocho specs compatibles con `tracer.17` (`bff` "cambió, compatible"; el resto solo bump de versión). Sin entrada en `rompimientos/`. `make lint-openapi`, `make check-estados` y `make check-registro` en verde; clientes Go compilan y pasan `go vet`.

**Archivos modificados:**
- `contracts/openapi/bff.yaml`, los otros siete specs y `_comunes.yaml` (solo `info.version`), `VERSION`, `contracts/events/INVENTARIO.md` (encabezado de ola)
- `packages/api-client-go/bff/bff.gen.go`, `packages/api-client-ts/src/openapi/bff.gen.ts`
- `CHANGELOG.md`

## 2026-10-22 [tracer.16] — tipo interno de incidencia en la lectura y auditoría de la descarga del expediente (AI27-59, AI27-80)

**Resumen:** Dos adiciones del equipo backend para cerrar el sprint, ambas en `operacion`+`bff`. (1) AI27-59: `ViajeDetalle` gana `incidencias_activas` con el `tipo_interno` de cada incidencia abierta, para que `bff` mapee la categoría curada del cliente (DEC-006); hasta ahora `ViajeDetalle` solo exponía `condiciones_activas` sin el tipo. (2) AI27-80: la descarga del expediente deja su rastro de auditoría, modelada como el comando `registrarDescargaViaje` en `operacion` que `bff` invoca al servir `descargarViaje`.

**Contexto:** Las dos brechas las reportó el equipo backend desde E2-T3 (AI27-59) y E6-T3 (AI27-80). Ambas verificadas ausentes en `tracer.14`.

AI27-59 es aditivo puro: el dato ya se persiste en `viajes.condicion_viaje` (`tipo_interno`, AI27-14) y `op_viajes` ya tiene `SELECT/INSERT/UPDATE` sobre esa tabla, así que exponerlo no cambia permisos ni captura. Se eligió embeber `incidencias_activas` en `ViajeDetalle` (no un `listarIncidencias` aparte) para evitar un segundo viaje de red. Schema nuevo `IncidenciaActiva`: vista reducida de `Incidencia` (sin `viaje_id` ni `resuelta_en`) porque va embebida en el viaje leído. `condiciones_activas` se conserva sin cambios. `tipo_interno` es consumo interno de `bff`; el curado para el cliente lo hace `bff`, nunca el contrato.

AI27-80 NO necesita ADR. El rastro lo escribe el interceptor de auditoría en la transacción de `operacion` con el rol dueño `op_auditoria` (que ya tiene INSERT por diseño), no un GRANT a `op_viajes`. La única excepción de GRANT cruzado del sistema (la de `op_asignacion`, gobernada por ADR 33) no se toca. Se modela como `POST /api/v1/viajes/{id}/descargas` → `registrarDescargaViaje` en `operacion`, porque deja un efecto persistente: `bff` conserva su GET público `descargarViaje` sin ensuciarlo con una escritura oculta. La redacción de la auditoría en `descargarViaje` sigue la ya usada por `descargarAdjunto` (E6-T4).

Número de ola: `tracer.15` (escritura de `fecha_hora_servicio`, E1-HU-003) entró a `-d` antes que esta ola. Esta rama se rebasó sobre ese `-d` y confirmó que `tracer.16` seguía libre antes de publicar (regla de versión §7; mismo caso que `tracer.5/6` y `7/8`). El rebase solo tocó `VERSION`, los ocho `info.version`, `package.json` y el orden del CHANGELOG; las adiciones de ambas olas a `operacion.yaml`/`bff.yaml` están en zonas distintas y coexisten sin conflicto semántico.

**Cambios:**
- `contracts/openapi/operacion.yaml`: `ViajeDetalle.incidencias_activas` (opcional) y schema nuevo `IncidenciaActiva`. Ruta `POST /api/v1/viajes/{id}/descargas` (`registrarDescargaViaje` → `Viaje`, errores 401/403/404).
- `contracts/openapi/bff.yaml`: la descripción de `descargarViaje` declara que cada descarga deja auditoría escrita por `operacion` vía `registrarDescargaViaje`. Sin cambio de superficie ni de schema en `bff`.
- Clientes Go y TS regenerados (`make generate`). `VERSION`, los ocho specs OpenAPI y el paquete TS a `0.1.0-tracer.16`.

**Compatibilidad:** aditivo. `make breaking-openapi` confirma los ocho specs compatibles con `tracer.15` (operacion y bff "cambió, compatible"; el resto solo bump de versión). Sin entrada en `rompimientos/`. `make lint-openapi` y `make check-estados` en verde; clientes Go compilan y pasan `go vet`.

**Archivos modificados:**
- `contracts/openapi/operacion.yaml`, `contracts/openapi/bff.yaml`, los otros seis specs (solo `info.version`), `VERSION`
- `packages/api-client-go/operacion/operacion.gen.go`, `packages/api-client-ts/src/openapi/operacion.gen.ts`, `packages/api-client-ts/src/openapi/bff.gen.ts`, `packages/api-client-ts/package.json`
- `CHANGELOG.md`

Nota: `packages/api-client-go/bff/bff.gen.go` no cambia; `oapi-codegen` no emite las descripciones de operación en el cliente Go, y el único cambio de `bff.yaml` fue la descripción de `descargarViaje`. El TS sí la refleja.

## 2026-10-22 [tracer.15] — escritura de `fecha_hora_servicio` sobre un viaje existente (E1-HU-003)

**Resumen:** Se agrega una operación de escritura de `fecha_hora_servicio` sobre un `viaje` ya creado, hasta ahora ausente: el contrato sólo permitía leer el campo (`ViajeInterno`) y escribirlo al crear (`CrearViajeEntrada`). El `Jefe Operativo` no puede aprobar una solicitud si falta la `fecha_hora_servicio` (guarda `fecha_hora_servicio_definida` de `SOLICITADO → APROBADO`, DEC-010 #2); si el cliente no la puso al crear, debía poder completarla antes de aprobar, y no existía ruta para hacerlo. Se publica `completarFechaHora` en `operacion` y su reenvío en `bff`, como `PATCH /api/v1/viajes/{id}/fecha-hora`.

**Contexto:** La brecha la reportó el equipo de `pf-web-frontend-internal` desde E8-T9 (satisface `E1-HU-003`), que hoy opera contra un `mock` MSW. El endpoint es el espejo exacto de `fijarEta` (ADR 20): escribe un campo suelto del viaje, NO es una transición de estado, y sólo exige que el viaje no esté en un estado terminal. Por eso su 409 reutiliza el `codigo` `viaje_en_estado_terminal` y NO `transicion_no_permitida` (ese código pertenece sólo a `transicionarViaje`, que valida contra el grafo). Decidido con el PO: la escritura se permite en cualquier estado no terminal (no sólo `SOLICITADO`); el esquema de entrada se llama `FechaHoraEntrada` para que el alias del frontend quede 1:1. A diferencia de `fijarEta`, el nuevo endpoint SÍ declara `404` en el spec (un id inexistente es un caso real del flujo de edición; `fijarEta` lo omite, desajuste spec↔código preexistente que no se replica). `completarFechaHora` devuelve `Viaje` en `operacion` y `ViajeDetalle` recompuesto en `bff`, igual que `fijarEta`, para refrescar el detalle sin un segundo GET. Número de ola: `tracer.14` es la última publicada en `-d` y no hay ola `15` tomada por tag ni por rama (verificado contra tags y `VERSION`), así que toma el siguiente libre, `tracer.15` (regla de versión de contratos §7).

**Cambios:**
- `contracts/openapi/operacion.yaml`: ruta `PATCH /api/v1/viajes/{id}/fecha-hora` (`completarFechaHora` → `Viaje`, errores 400/401/403/404/409 con `codigo` `viaje_en_estado_terminal`). Schema nuevo `FechaHoraEntrada` (`fecha_hora_servicio` requerido, `MarcaTiempo`).
- `contracts/openapi/bff.yaml`: mismo path, reenvía a `operacion.completarFechaHora`, `200` → `ViajeDetalle`. Schema nuevo `FechaHoraEntrada` espejo del de `operacion`.
- Clientes Go y TS regenerados (`make generate`). `VERSION`, los ocho specs OpenAPI y el paquete TS a `0.1.0-tracer.15`.

**Compatibilidad:** aditivo. `make breaking-openapi` confirma los ocho specs compatibles con `tracer.14` (operacion y bff "cambió, compatible"; el resto solo bump de versión). Sin entrada en `rompimientos/`. `make verify`, `make lint-openapi` y `make check-estados` en verde; clientes Go compilan y pasan `go vet`.

**Archivos modificados:**
- `contracts/openapi/operacion.yaml`, `contracts/openapi/bff.yaml`, los otros seis specs (solo `info.version`), `VERSION`
- `packages/api-client-go/bff/bff.gen.go`, `packages/api-client-go/operacion/operacion.gen.go`, `packages/api-client-ts/src/openapi/bff.gen.ts`, `packages/api-client-ts/src/openapi/operacion.gen.ts`, `packages/api-client-ts/package.json`
- `CHANGELOG.md`

## 2026-10-21 [tracer.14] — catch-up de la colección de bandeja en `mensajeria` (M3)

**Resumen:** `listarTrabajoBandeja` deja de ser un listado paginado genérico y se vuelve el bootstrap/catch-up de la colección de bandeja que ADR 28 exige. Devuelve la `revision` monotónica de la colección (cursor de dominio, ADR 28 §3), acepta `desde_revision` para pedir solo los cambios posteriores, y responde `409 stream_resync_required` cuando esa revisión quedó fuera de la ventana retenida (ADR 28 §5). Es el mismo patrón que la conversación ya tenía (`obtenerConversacion` → `ultima_secuencia`, `listarMensajes?despues_de=`), trasladado del agregado "mensajes de una conversación" al agregado "conversaciones de una bandeja".

**Contexto:** El catch-up de bandeja (M3) estaba declarado fuera de alcance desde `tracer.7` ("bootstrap/catch-up de la colección de bandeja… rutas aún sin congelar") y no entró en ninguna ola 8–13 (verificado contra el CHANGELOG y el `mensajeria.yaml` de `tracer.13`). El protocolo ya estaba decidido en ADR 28; solo faltaba plasmarlo en el contrato. No requiere decisión de producto nueva. Se modela como agregado propio (`TrabajoBandeja`, no `PaginaConversaciones`) porque la bandeja tiene una revisión de colección que el listado por alcance (`listarConversaciones`) no tiene; meter `revision` en `PaginaConversaciones` habría obligado a `listarConversaciones` a declarar un cursor que no le corresponde. `listarConversaciones` no cambia. Número de ola: `tracer.13` es la última publicada en `-d` y no hay `14` tomada por tag ni por rama (verificado), así que esta toma el siguiente libre, `tracer.14` (regla de versión de contratos §7).

**Cambios:**
- `contracts/openapi/mensajeria.yaml`: `listarTrabajoBandeja` gana el parámetro opcional `desde_revision`, la respuesta `409 ResyncRequerido` (`codigo` `stream_resync_required`) y cambia su 200 de `PaginaConversaciones` a `TrabajoBandeja`. Schemas nuevos: `RevisionBandeja` (int64 monotónico de colección) y `TrabajoBandeja` (`items`, `revision`, `cursor_siguiente`). Respuesta reutilizable nueva `ResyncRequerido`.
- Clientes Go y TS regenerados (`make generate`). `VERSION`, los ocho specs OpenAPI y el paquete TS a `0.1.0-tracer.14`.

**Compatibilidad:** aditivo. `make breaking-openapi` confirma los ocho specs compatibles con `tracer.13` (mensajeria "cambió, compatible": el 200 pasa a un superconjunto, el parámetro y el 409 son nuevos; el resto solo bump de versión). Sin entrada en `rompimientos/`. `make lint-openapi` y `make check-estados` en verde; clientes Go compilan.

**Archivos modificados:**
- `contracts/openapi/mensajeria.yaml`, los otros siete specs (solo `info.version`), `VERSION`
- `packages/api-client-go/mensajeria/mensajeria.gen.go`, `packages/api-client-ts/src/openapi/mensajeria.gen.ts`, `packages/api-client-ts/package.json`
- `CHANGELOG.md`

## 2026-10-21 [tracer.13] — superficie interna de avance del viaje en `bff` (E8-T8)

**Resumen:** Se amplía el contrato de `bff` con la superficie interna de avance del viaje que pide el frontend interno para la pantalla de detalle (E8-T8 / `E1-HU-005`), hasta ahora ausente: el frontend habla sólo con `bff` y la lectura publicada (`seguirViaje`) es la vista curada para cliente, sin `estado` canónico ni condiciones, así que no sirve para derivar acciones desde la máquina de estados. Se agregan tres reenvíos a `operacion`: leer el detalle interno con estado canónico, registrar una transición y fijar el ETA manual.

**Contexto:** Las tres piezas ya existen en `operacion.yaml` (`obtenerViaje` → `ViajeDetalle`, `transicionarViaje`, `fijarEta`), marcado "Consumido por `bff`, nunca por el frontend directo"; el frontend no puede llamarlo. La brecha quedó fuera de olas previas del tracer (handoff), no es un error de diseño. Los schemas nuevos de `bff` son espejo de las formas de `operacion` con los mismos nombres (`ViajeDetalle`, `TransicionEntrada`, `EtaEntrada`, `CondicionAbierta`), para que el consumidor migre por cambio de importación, no por reescritura. El `estado` se expone como token `string` igual que `ViajeResumen`: el enum `EstadoViaje` vive y se valida en `operacion`/`contracts/estados` (gate `check-estados`), el `bff` no lo replica para no crear una segunda fuente de verdad sin ese check. El 200 de transición y ETA devuelve `ViajeDetalle` para refrescar la vista sin un segundo GET. Número de ola: `tracer.12` es la última publicada en `-d` y no hay ola `13` tomada por tag ni por rama de trabajo (verificado contra tags remotos y `VERSION` de cada rama `feat/*`), así que esta toma el siguiente libre, `tracer.13` (regla de versión de contratos §7).

**Cambios:**
- `contracts/openapi/bff.yaml`: rutas `GET /api/v1/viajes/{id}/detalle` (`obtenerViajeInterno` → `ViajeDetalle`), `POST /api/v1/viajes/{id}/transiciones` (`transicionarViaje`, 409 con `codigo` `transicion_no_permitida`) y `PATCH /api/v1/viajes/{id}/eta` (`fijarEta`, 409 con `codigo` `viaje_en_estado_terminal`). Schemas nuevos: `ViajeDetalle`, `ViajeInterno`, `CondicionAbierta`, `TransicionEntrada`, `EtaEntrada`. Reutiliza `Id`, `MarcaTiempo` y las respuestas de error de `_comunes.yaml`.
- Clientes Go y TS regenerados (`make generate`). `VERSION`, los ocho specs OpenAPI y el paquete TS a `0.1.0-tracer.13`.

**Compatibilidad:** aditivo. `make breaking-openapi` confirma los ocho specs compatibles con `tracer.12` (bff "cambió, compatible"; el resto solo bump de versión). Sin entrada en `rompimientos/`. `make lint-openapi`, `make check-estados` y `go build`/`go vet` en verde.

**Archivos modificados:**
- `contracts/openapi/bff.yaml`, los otros siete specs (solo `info.version`), `VERSION`
- `packages/api-client-go/bff/bff.gen.go`, `packages/api-client-ts/src/openapi/bff.gen.ts`, `packages/api-client-ts/package.json`
- `CHANGELOG.md`

## 2026-10-19 [tracer.12] — superficie de adjuntos/evidencia de `operacion` (E6-T4)

**Resumen:** Se agrega al contrato de `operacion` la superficie de adjuntos/evidencia del viaje (E6-T4 / `E6-HU-027`), hasta ahora ausente: el schema `bitacora` tenía un `TODO` de adjuntos y la historia técnica estaba bloqueada por "contrato primero". Se publican tres operaciones bajo `/api/v1/viajes/{id}/adjuntos` siguiendo el patrón ya contratado para `mensajeria` (intención de subida con URL de vida corta; los bytes nunca pasan por el servicio).

**Contexto:** E6-T4 pide un módulo de adjuntos en `operacion` (schema `bitacora`), con metadatos en Postgres y bytes en el almacenamiento de objetos (propuesta ADR 32: MinIO). La forma se deriva del patrón ya contratado en `mensajeria.yaml` (`crearIntencionSubida` → `IntencionSubida`), adaptado al viaje: clave de objeto alcanzada por tenant/viaje, estado de escaneo antivirus, y acceso auditado (E1-T7, DEC-040: cero adjuntos no bloquea el cierre). Esto desbloquea E6-T4 por el lado del contrato; la implementación (tabla `adjunto_viaje`, adaptador de object storage) sigue pendiente y depende de que ADR 32 fije el almacenamiento. Número de ola: `tracer.11` es la última publicada en `-d`, así que esta toma el siguiente libre, `tracer.12` (regla de versión de contratos §7).

**Cambios:**
- `contracts/openapi/operacion.yaml`: tag `adjuntos` y rutas `GET /api/v1/viajes/{id}/adjuntos` (listar metadatos), `POST /api/v1/viajes/{id}/adjuntos/intenciones-subida` (autorización de subida de vida corta) y `GET /api/v1/viajes/{id}/adjuntos/{aid}/descarga` (autorización de descarga de vida corta, auditada). Schemas nuevos: `Adjunto`, `PaginaAdjuntos`, `IntencionSubidaAdjuntoEntrada`, `IntencionSubidaAdjunto`, `DescargaAdjunto`. Reutiliza `Id`, `MarcaTiempo` y las respuestas de error de `_comunes.yaml`.
- Clientes Go y TS regenerados (`make generate`). `VERSION`, los ocho specs OpenAPI y el paquete TS a `0.1.0-tracer.12`.

**Compatibilidad:** aditivo. `make breaking-openapi` confirma los ocho specs compatibles con `tracer.11` (operacion "sin romper", el resto sin cambios). Sin entrada en `rompimientos/`. `make verify` y `make generate` reproducibles en verde.

**Archivos modificados:**
- `contracts/openapi/operacion.yaml`, los otros siete specs (solo `info.version`), `VERSION`
- `packages/api-client-go/operacion/operacion.gen.go`, `packages/api-client-ts/src/openapi/operacion.gen.ts`, `packages/api-client-ts/package.json`
- `CHANGELOG.md`

## 2026-10-19 [tracer.11] — superficie de gobierno de `identidad` (sujetos y roles)

**Resumen:** Se publica la superficie HTTP de administración de usuarios y roles de `identidad` (E4-T6), hasta ahora ausente del contrato (brecha G-2): el backend de gobierno estaba listo pero no podía exponerse ni pasar al front porque no existían tipos a los que pegarse. Se agregan las rutas bajo `/api/v1/sujetos` y los dos eventos de ciclo de vida que faltaban, `sujeto.creado` y `sujeto.reactivado`.

**Contexto:** `identidad` es dueño del gobierno de sujetos y roles; el servicio compromete cada cambio en local (estado + traza + outbox) y sincroniza el IdP después (DEC-085, local manda). El contrato publicado (`tracer.9`) solo tenía la superficie de sesión. La forma de las operaciones y de los eventos se deriva del backend ya implementado (`pf-svc-identidad/internal/gobierno`), no se inventa. El payload de `sujeto.creado`/`sujeto.reactivado` toma como precedente `sujeto.desactivado`/`rol.asignado` (agregado + tenant + marca de tiempo; `creado` suma el `rol` inicial). Número de ola: `tracer.10` ya está tomado por la marca de frescura de `reportes` en `-d`/`-q`, así que esta ola toma el siguiente libre, `tracer.11` (regla de versión de contratos §7).

**Cambios:**
- `contracts/openapi/identidad.yaml`: tag `gobierno` y rutas `POST /api/v1/sujetos` (alta con rol), `GET /api/v1/sujetos/{id}` (detalle), `DELETE /api/v1/sujetos/{id}` (desactivar), `POST /api/v1/sujetos/{id}/reactivacion`, `GET /api/v1/sujetos/{id}/historial` (traza paginada por cursor) y `PUT /api/v1/sujetos/{id}/rol` (asignar inicial o reemplazar). Schemas nuevos: `AltaSujetoEntrada`, `Sujeto`, `SujetoDetalle`, `AsignacionRolEntrada`, `CambioAdministrativo`, `PaginaHistorial`. Reutiliza `Rol`, `Id`, `Cursor`, `MarcaTiempo` y las respuestas de error de `_comunes.yaml`.
- `contracts/events/ai27/eventos/v1/sujeto.proto`: mensajes `SujetoCreado` (con `rol`) y `SujetoReactivado`.
- `contracts/events/registro.tipos.yaml` e `INVENTARIO.md`: filas `sujeto.creado` y `sujeto.reactivado` (productor `identidad`, consumidores `catalogos`/`mensajeria`/`reportes`, agregado `sujeto_id`, amplia). El registro pasa de 26 a 28 tipos.
- Clientes Go y TS regenerados (`make generate`). `VERSION`, los ocho specs OpenAPI y el paquete TS a `0.1.0-tracer.11`.

**Compatibilidad:** aditivo. `make breaking-openapi` confirma los ocho specs compatibles con `tracer.9`; `buf breaking` de eventos compatible con `pf-contracts-m`. Sin entrada en `rompimientos/`. `make verify` y `make generate` reproducibles en verde.

**Archivos modificados:**
- `VERSION`
- `contracts/openapi/identidad.yaml`
- `contracts/openapi/_comunes.yaml`, `bff.yaml`, `catalogos.yaml`, `mensajeria.yaml`, `operacion.yaml`, `realtime.yaml`, `reportes.yaml` (solo bump de `info.version`)
- `contracts/events/ai27/eventos/v1/sujeto.proto`
- `contracts/events/registro.tipos.yaml`, `contracts/events/INVENTARIO.md`
- `packages/api-client-go/identidad/identidad.gen.go`
- `packages/api-client-go/eventos/ai27/eventos/v1/sujeto.pb.go`
- `packages/api-client-go/registro/registro.gen.go`
- `packages/api-client-ts/src/openapi/identidad.gen.ts`
- `packages/api-client-ts/src/eventos/ai27/eventos/v1/sujeto_pb.ts`
- `packages/api-client-ts/src/registro/registro.gen.ts`
- `packages/api-client-ts/package.json`


## 2026-10-16 [tracer.10] — marca de frescura en las lecturas de `reportes`

**Resumen:** Se agrega la marca de frescura a las dos respuestas de lectura de `reportes` (`ReporteViajes` y `ReporteEstados`): `proyeccion_al` (instante hasta el que la proyección aplicó eventos) y `stale` (booleano de obsolescencia contra el techo del servicio). Es la ola que destraba las lecturas HTTP de E6 (E6-T2 dashboard), que estaban bloqueadas por R3: una proyección por eventos puede ir atrasada y la respuesta debe declararlo.

**Contexto:** `reportes` es un modelo de lectura por eventos (ADR 18). Su arquitectura obliga a que "todo reporte devuelva la marca de frescura de las proyecciones que usó" (`reportes.md` (i)): sin ella, un reporte congelado por un consumo detenido se ve idéntico a un periodo tranquilo. El audit lo dejaba pendiente de congelar (compuerta G3). El techo de frescura es configuración del servicio, no del contrato: el contrato solo expone el booleano `stale` ya resuelto. Variante elegida con el Lead: instante + bandera, no segundos de retraso derivables.

**Cambios:**
- `contracts/openapi/reportes.yaml`: `ReporteViajes` y `ReporteEstados` suman `proyeccion_al` (`MarcaTiempo`, nullable) y `stale` (boolean), ambos **opcionales** (no entran a `required`). El servicio los llena siempre; `proyeccion_al` es null solo si la proyección aún no aplicó ningún evento.
- Clientes Go y TS de `reportes` regenerados (`make generate`): `ProyeccionAl *MarcaTiempo`, `Stale *bool` en ambos schemas.
- `VERSION`, los ocho specs OpenAPI y el paquete TS a `0.1.0-tracer.10` (solo `reportes` cambió de forma; los demás suben de número porque el tag versiona el paquete completo).

**Compatibilidad:** aditivo. `make breaking-openapi` confirma los ocho specs compatibles con `tracer.9`. Sin entrada en `rompimientos/`. `make verify` y `make generate` reproducibles en verde.

**Archivos modificados:**
- `VERSION`
- `contracts/openapi/reportes.yaml`
- `contracts/openapi/_comunes.yaml`, `bff.yaml`, `catalogos.yaml`, `identidad.yaml`, `mensajeria.yaml`, `operacion.yaml`, `realtime.yaml` (solo bump de `info.version`)
- `packages/api-client-go/reportes/reportes.gen.go`
- `packages/api-client-ts/src/openapi/reportes.gen.ts`
- `packages/api-client-ts/package.json`

## 2026-10-14 [tracer.9] — superficie SSE mínima de `realtime`

**Resumen:** Se publica `contracts/openapi/realtime.yaml` con la parte CONGELADA de la superficie SSE de `realtime` (DEC-090): la operación `GET /api/v1/stream` y la respuesta `409 stream_resync_required`. Es la ola que destraba el scaffold de `realtime` (prompt 08) para montar la ruta del stream contra un contrato real.

**Contexto:** camino 2 acordado con el Lead (contrato SSE antes del scaffold). Al medir contra ADR 28 y `realtime.md` (f), solo `GET /api/v1/stream` y el `409` están congelados; el resto del protocolo SSE y la emergencia de mensajería siguen pendientes de congelar en la arquitectura (DEC-090). No se contrata lo pendiente.

**Cambios:**
- `contracts/openapi/realtime.yaml` (nuevo): `GET /api/v1/stream` (SSE, sin `?canales`, `Last-Event-ID` opcional, cabeceras `Cache-Control: no-cache` y `X-Accel-Buffering: no`, respuesta 200 `text/event-stream`), y `409` con `codigo` de máquina `stream_resync_required`.
- Tooling: `realtime` entra a `generar.sh`, `breaking-openapi.sh`, `lint-openapi`, `check-tags.sh` y al consumidor limpio de `contract-tests.sh`.
- `VERSION`, los siete specs previos y el paquete TS a `0.1.0-tracer.9`.

**Compatibilidad:** aditivo. `make breaking-openapi` compatible con `tracer.8` en los siete specs previos; `realtime` es spec nuevo sin línea base. `buf breaking` de eventos compatible con `tracer.8` (esta ola no cambia eventos). Sin entrada en `rompimientos/`.

**Fuera de esta ola, por pendiente declarado (no inventado):**
- `GET /api/v1/conexiones`: solo mencionada en `realtime.md` (f), sin esquema.
- La codificación concreta del `id` SSE / `Last-Event-ID`: la fuente la deja "en el contrato pendiente". OpenAPI describe la operación HTTP, no los frames SSE.
- Eventos de control de línea (`stream.stale`, anuncio de heartbeat): viven en los frames, pendientes (ADR 28 §6).
- Emergencia de mensajería: sus esquemas y nombres no están congelados (`mensajeria.md` (l), ADR 21, E7). Espera una ola futura.


## 2026-10-14 Sprint 3: superficie de catálogos, estadías y descarga

**Resumen:** Se agrega la superficie contractual (OpenAPI) de cinco historias
técnicas del Sprint 3: custodios versionados (AI27-74), contratos/SLA versionados
(AI27-76) y catálogos de tipo (AI27-75) en `catalogos`; estadías (AI27-14) en
`operacion`; y descarga del expediente de un viaje (AI27-80) en `bff`. Todo
aditivo. Rama `feat/contract-changes-for-sprint`, sobre `tracer.7`.

**Contexto:** el cierre de la ola —bump de `VERSION` a la siguiente prerelease
(p. ej. `tracer.8`), `info.version` de los specs y manifiesto— es un paso aparte;
**esta entrada aún no corresponde a un tag publicado** (de ahí `[sin publicar]`).
Decisiones base: ADR 31, ADR 5/DEC-017, DEC-055, DEC-022 #4/DEC-025, DEC-013/
DEC-038, DEC-009/DEC-039, DEC-022 #7/DEC-023; propiedades P1/P8/P17.

**Cambios:**
- `catalogos.yaml` — **AI27-74 (E5-T2):** `Custodio` suma `version`,
  `vigencia_desde`/`vigencia_hasta` y `usuario_id` (referencia a `identidad` por
  identificador, no FK — P1), todos opcionales; `listarCustodios` acepta `ids`
  (lote); rutas nuevas `GET /custodios/{id}?a_fecha`, `POST /custodios`,
  `PATCH /custodios/{id}`; esquemas `CustodioEntrada`/`CustodioCambios`.
- `catalogos.yaml` — **AI27-76 (E5-T4):** `version` opcional en `Contrato` y
  `Sla`; rutas nuevas `POST`/`PATCH /contratos` y `/sla`; esquemas
  `ContratoEntrada`/`ContratoCambios`/`SlaEntrada`/`SlaCambios`. Informativos en
  V1 (DEC-022 #4/DEC-025): no condicionan ningún flujo de E1.
- `catalogos.yaml` — **AI27-75 (E5-T3):** recurso único parametrizado
  `GET`/`POST /catalogos-tipo/{tipo}` y `PATCH /catalogos-tipo/{tipo}/{id}`; tag
  `catalogos-tipo`; `TipoCatalogo` (`tipos_servicio`, `lineas_transporte`,
  `tipos_unidad`, `tipos_custodia`, `zonas_riesgo`), `ValorCatalogo` y entrada/
  cambios/página. `zonas_riesgo` solo como lista (sin geometría, DEC-017);
  desactivar = `PATCH estado: inactivo`.
- `operacion.yaml` — **AI27-14 (E1-T6):** sub-recurso de estadías
  `GET`/`POST /viajes/{id}/estadias` y `PATCH /viajes/{id}/estadias/{eid}`
  (409 `estadia_ya_cerrada`); tag `estadias`; `MotivoEstadia`,
  `EjeAutorizacionEstadia`, `Estadia` (inicio + cierre), entrada/cierre/página.
  Sin clasificación `prolongada` ni umbral (DEC-038). **No** toca
  `contracts/estados/`: `EstadoViaje` intacto.
- `bff.yaml` — **AI27-80 (E6-T3):** `GET /viajes/{id}/descarga` (`descargarViaje`,
  solo interno); tag `descarga`; `DescargaViaje` + `FichaTecnicaDescarga` +
  `EntradaBitacoraDescarga` + `RegistroAuditoriaDescarga`. Un solo viaje (sin
  lote, DEC-023); sin cuenta espejo ni `clave_amago` (DEC-009/039).
- Clientes Go y TS de `catalogos`, `operacion` y `bff` regenerados desde las
  fuentes anteriores.

**Compatibilidad:** aditivo (campos opcionales, rutas y esquemas nuevos). Sin
entrada en `rompimientos/`. `redocly lint` en verde para los tres specs. El gate
completo (`check-reproducible`, `breaking-openapi`, `buf breaking`,
`contract-tests`) queda **pendiente de CI**. No se tocaron eventos ni estados.

**Archivos:**
- `contracts/openapi/catalogos.yaml`,
  `packages/api-client-go/catalogos/catalogos.gen.go`,
  `packages/api-client-ts/src/openapi/catalogos.gen.ts`
- `contracts/openapi/operacion.yaml`,
  `packages/api-client-go/operacion/operacion.gen.go`,
  `packages/api-client-ts/src/openapi/operacion.gen.ts`
- `contracts/openapi/bff.yaml`,
  `packages/api-client-go/bff/bff.gen.go`,
  `packages/api-client-ts/src/openapi/bff.gen.ts`

## 2026-10-14 [tracer.7] — ola contractual 2: conversación de `mensajeria`

**Resumen:** Se publica la superficie que destraba el scaffold de
`pf-svc-mensajeria` (prompt 07): su spec OpenAPI, los eventos de conversación
sobre la superficie restringida, el sobre vivo con audiencia explícita, los
eventos de sujeto/RBAC de `identidad` y la lectura por lote de clientes en
`catalogos`. Es la ola que DEC-065 llamaba `tracer.5` (renumerada por DEC-087).

**Contexto:** el Lead decidió el 2026-10-14 partir la ola 2: conversación en
`tracer.7`; bootstrap/catch-up de bandeja y emergencia en `tracer.8`, porque la
arquitectura todavía no congela sus rutas ni nombres (mensajeria.md (f), (l)).
También decidió un sobre aparte para el tema restringido (no ampliar `Sobre`) y
que M6 (eventos de `identidad`) y la lectura por lote de `catalogos` entren aquí.

**Cambios:**
- `contracts/openapi/mensajeria.yaml` (nuevo): bandeja/trabajo, conversaciones,
  mensajes con `antes_de`/`despues_de` y envío idempotente por
  `client_message_id`, reclamo/liberación/transferencia con versión esperada
  (409 `conflicto_version_reclamo`), recibos, atendida, intención de subida de
  adjuntos y auditoría. Sin plantillas (DEC-023).
- `contracts/events/.../sobre_vivo.proto` (nuevo): `SobreVivo` con
  `cursor_dominio`, `audience_version` y `target_sujeto_ids` (ADR 28 §4).
- `contracts/events/.../conversacion.proto` (nuevo): `conversacion.abierta`,
  `.enrutada`, `.reclamada`, `.liberada`, `.transferida`, `.atendida`,
  `.cerrada`; `mensaje.creado`; `recibo.entregado`/`.leido`;
  `membresia.cambiada`. Sensibilidad **restringida**.
- `contracts/events/.../sujeto.proto` (nuevo): `sujeto.desactivado`,
  `rol.asignado`, `rol.revocado` de `identidad`. Superficie amplia.
- `catalogos.yaml`: `listarClientes` acepta `ids` (lectura por lote), mismo
  patrón que `listarVehiculos`. Aditivo.
- Registro e `INVENTARIO.md`: 14 tipos nuevos; `mensajeria` pasa a consumir
  `catalogo.actualizado`.
- Tooling: `mensajeria` entra a la lista de servicios de `generar.sh`,
  `breaking-openapi.sh`, `lint-openapi`, `check-tags.sh` y al consumidor limpio
  de `contract-tests.sh` (con aserciones de valor sobre sensibilidad);
  `check-registro` reconoce `SobreVivo` como envoltura.
- `VERSION`, los seis specs y el paquete TS a `0.1.0-tracer.7`.

**Compatibilidad:** aditivo. `make breaking-openapi` compatible con `tracer.6`
en los seis specs; `buf breaking` contra el tag `v0.1.0-tracer.6` compatible.
Sin entrada en `rompimientos/`.

**Notas (brechas declaradas, no inventadas):**
- `usuario.desactivado` (nombre de `mensajeria.md` (g)) se publicó como
  `sujeto.desactivado`, el nombre del productor (`identidad.md` (g)).
- El alcance por `cliente` del `ejecutivo` no viaja en ningún evento: su forma
  está pendiente (DEC-045). Sin él, el pool se calcula solo por rol.
- "Datos de contacto" del cliente no tienen forma definida en ninguna fuente;
  no se agregaron. V1 no notifica al cliente (DEC-023), así que no bloquean.
- oapi-codegen genera `SecuenciaMensaje` y `VersionReclamo` como **alias** de
  `int64`: el contrato no impide convertirlos. Los tipos distintos sin
  conversión los declara el módulo `mensajeria` (prompt 07).

## 2026-10-13 [tracer.6] — cierre de ola (VERSION + specs + paquete TS)

**Resumen:** Se publica **`v0.1.0-tracer.6`**, que cierra la ola de la superficie
de vehículos de `catalogos` (E5-T1, AI27-73). El cambio de forma lo hizo Gonzalo
en el commit anterior; esta entrada corrige el número de ola y cierra la
publicación.

**Contexto (por qué tracer.6 y no tracer.5):** el commit de E5-T1 subía `VERSION`
a `tracer.5`, pero `tracer.5` ya se había consumido en el MFA de identidad
(entrada siguiente). El cambio de vehículos quedó encima de `tracer.5` sin bump
real. Esta ola lo publica como **tracer.6**. Decisión del Lead: tracer.6 se
adelanta para E5-T1; la ola 2 (mensajería, SSE, emergencias) pasa a tracer.7.

**Cambios:**
- `VERSION`: `0.1.0-tracer.5` → `0.1.0-tracer.6`.
- Los seis specs OpenAPI a `0.1.0-tracer.6` (solo `catalogos` cambió de forma; los
  otros cinco suben de número porque el tag versiona el paquete completo).
- `packages/api-client-ts/package.json`: `version` y descripción a tracer.6.

**Compatibilidad:** `make breaking-openapi` confirma los seis specs **compatibles**
con tracer.5. Todo el cambio de E5-T1 es aditivo (rutas nuevas, campos
opcionales): **no** hay entrada en `rompimientos/`. `generate` no modificó ningún
artefacto generado (reproducible). `make verify` y `make test-breaking-gate` en
verde.

## 2026-10-13 [tracer.5] — superficie de vehículos de catalogos (E5-T1)

**Resumen:** Se completa en el contrato de `catalogos` la superficie de
vehículos que E5-T1 (AI27-73) necesita: lectura por lote (C4), respuesta
versionada (C6) y escritura administrativa POST/PATCH (C7), más la lectura
vigente-a-una-fecha (C9). Todos los cambios son **aditivos** (ninguno rompe a los
consumidores de `tracer.4`). Preparado en `AI27-73/E5-T1-registro-de-unidades`;
el Lead publica el tag `v0.1.0-tracer.5`. Esta ola comparte versión con el
cambio de segundo factor de identidad (abajo); al mergear ambas ramas se
reconcilia `VERSION`/`info.version`.

**Cambios (tres commits temáticos):**
- **C6 — respuesta versionada** (`contracts/openapi/catalogos.yaml`): al esquema
  `Vehiculo` se agregan `version` (entero ≥1) y `vigencia_desde`/`vigencia_hasta`.
  **Opcionales** por evolución expand/contract: no rompen a `tracer.4`; el
  servicio los llena siempre. Sube `VERSION` a `0.1.0-tracer.5` y alinea
  `packages/api-client-ts/package.json`.
- **C4 — lectura por lote** (`catalogos.yaml`): `listarVehiculos` acepta el query
  param `ids` (separado por coma, `style: form, explode: false`), mutuamente
  excluyente con `cursor`; respuesta `400` nueva. Evita el patrón N+1 de los
  consumidores.
- **C7 — escritura administrativa** (`catalogos.yaml`): `POST /api/v1/vehiculos`
  (`crearVehiculo`) y `PATCH /api/v1/vehiculos/{id}` (`actualizarVehiculo`), con
  los esquemas `VehiculoEntrada` y `VehiculoCambios`. El PATCH crea una nueva
  versión y emite `catalogo.actualizado` en la misma transacción (P17), sin
  sobrescribir. Incluye `GET /api/v1/vehiculos/{id}` con `?a_fecha`
  (`obtenerVehiculo`, C9), que comparte el path nuevo.

**Regenerado (contrato primero, no editado a mano):**
- `packages/api-client-go/catalogos/catalogos.gen.go`
- `packages/api-client-ts/src/openapi/catalogos.gen.ts`
- Verificado con `make generate` en entorno Linux: la regeneración es
  reproducible (sin deriva en los artefactos de `catalogos`).

**Impacto:**
- `pf-svc-catalogos`: habilita la Fase B de E5-T1 (implementar lecturas con
  `version`, lote, y la escritura POST/PATCH con outbox). Sube su pin a
  `v0.1.0-tracer.5`.
- Consumidores de `tracer.4` (`operacion`, `bff`, `reportes`): sin impacto;
  `tracer.5` es superconjunto compatible.

**Notas:**
- Decisiones abiertas para revisión: `cliente_id` requerido en `VehiculoEntrada`;
  `cliente_id` no editable en `VehiculoCambios`; `409 Conflicto` declarado en
  POST/PATCH sin que el modelo de datos tenga aún una restricción de unicidad.

## 2026-10-16 [tracer.5]

**Resumen:** Se publica **`v0.1.0-tracer.5`** con soporte para segundo factor en la emisión de sesión.

**Cambios:**
- `contracts/openapi/identidad.yaml`:
  - Version bumpeada: `0.1.0-tracer.4` → `0.1.0-tracer.5`
  - `CredencialesEntrada`: agregado campo `segundo_factor` (type: string, nullable)
  - Descripción: el OTP/TOTP es opcional en V1, requerido en V2+. Keycloak lo valida; identidad solo lo transporta.
  - Referencias: DEC-031 (ADR 13), DEC-065 (A-3), DEC-087 (A-15)
  
**Impacto:**
- Backend (`pf-svc-identidad`): puede cambiar firma de `EmitirSesion` para recibir `Credentials` con `SegundoFactor`
- Frontend (`pf-web-frontend-client`): puede agregar campo OTP en formulario de login
- Auditoría interna: se registra en tabla `cambio_identidad` con tipo `sesion.emitida` y flag `segundo_factor_utilizado` en detalle

**Notas:**
- Campo es nullable en V1 para mitigar desincronización entre servicios
- Keycloak ya está configurado con TOTP obligatorio en flujo directo (realm-ai27.json)
- Todos los tipos Go y TypeScript se regeneran automáticamente desde el contrato
- Cierre de ola (Lead): se subió `VERSION` y los seis specs OpenAPI a `0.1.0-tracer.5`
  (los otros cinco sin cambio de forma; suben de número porque el tag versiona el
  paquete completo), más `package.json` del cliente TS. `breaking-openapi` confirma
  los seis compatibles con tracer.4: cambio aditivo, sin entrada en `rompimientos/`.
  Decisión del Lead: tracer.5 se adelanta para el MFA de E4; la ola 2 (mensajería,
  SSE, emergencias) pasa a tracer.6.

## 2026:10:08 13:36

**Resumen:** Se preparó (sin publicar) la **ola contractual 1**, `v0.1.0-tracer.4`,
para `catalogos` y `operacion`. Es la ola que DEC-065 renumeró desde `tracer.3`
tras el retiro de `tracer.2`. Incluye las correcciones respaldadas por fuentes
(aptitud informativa y `APTO_PARA_SALIDA` opcional), la brecha de contrato del
roster de `unidades`, el renombre del átomo a `vehiculo`, el ETA de ADR 20, y un
mecanismo de allowlist de rupturas intencionales por versión. Nada se commitea,
etiqueta ni publica: queda en `feat/tracer-4-ola-1` para que el Lead publique.

**Cambios respaldados por fuentes (DEC-055 / DEC-043 / ADR 31 / ADR 20):**
- `contracts/estados/viaje.estados.yaml`: se retira la guarda `ningun_recurso_no_apto`
  de `ASIGNADO → APTO_PARA_SALIDA`; se agregan `ASIGNADO → EN_EMBARQUE` y
  `ASIGNADO → EN_TRANSITO` (disparador operador) que hacen `APTO_PARA_SALIDA`
  opcional (DEC-043 #1); la guarda de `APROBADO → ASIGNADO` se renombra a
  `escolta_reservada` (ya no menciona aptitud; la aptitud no gatea en V1,
  DEC-055). El enum de 13 estados no cambia.
- `contracts/openapi/operacion.yaml` `asignarRecursos`: el único rechazo 409 queda
  `recurso_no_disponible` (reserva fallida); se elimina `recurso_no_apto`.
  Descripciones reescritas en términos de escolta.
- `contracts/openapi/catalogos.yaml`: la aptitud es informativa en V1; `catalogos`
  devuelve `apto` true/false y NUNCA "desconocida" — ese valor lo calcula el
  consumidor (operacion/bff). Se corrigieron los textos que podían sugerir lo
  contrario.

**Cambios de la ola (D1–D6):**
- **D6b (ruptura):** el átomo de `catalogos` se renombra a `vehiculo`:
  `/api/v1/unidades`→`/api/v1/vehiculos`, `.../aptitud` igual, esquema
  `Unidad`→`Vehiculo`, `listarUnidades`→`listarVehiculos`,
  `aptitudUnidad`→`aptitudVehiculo`.
- **D6a:** roster mínimo de `unidades` en `operacion` (brecha de ADR 33): listar,
  crear, obtener y modificar (activar/desactivar vía `activa`). `Unidad` del roster
  con `id`, `vehiculo_id` (referencia, no FK), `custodios_ids` (1..2), `activa`, y
  `tipo` (patrulla|moto) SOLO LECTURA derivado del vehículo. Queda anotada como
  pregunta abierta de Operación si un custodio puede estar en varias unidades (no
  se restringe en el contrato).
- **D1:** la respuesta de `asignarRecursos` lleva aptitud informativa por átomo
  (`unidades[].aptitud[]` con `recurso`, `recurso_id`, `estado`
  apto|no_apto|desconocido, `motivos`). Sin aptitud agregada por unidad.
- **D2 (ruptura):** `AsignacionEntrada` pasa a `unidades_ids` (1..N);
  `ReasignacionEntrada` manda la escolta completa (`unidades_ids` ≥1 y `motivo`,
  ambos obligatorios) y pierde `custodios_ids`/`unidad_id`.
- **D3 (ruptura):** en `viaje.proto`, `ViajeAsignado`/`ViajeReasignado` marcan
  `unidad_id` y `custodios_ids` como `reserved` (número y nombre) y agregan
  `repeated string unidades_ids`. No se crea v2.
- **D5:** `PATCH /api/v1/viajes/{id}/eta` con 409 `viaje_en_estado_terminal`;
  `Viaje.eta_estimado` fecha-hora nullable (reemplaza el objeto `Eta` con
  `obsoleto`); `operacion` no expone `stale`, lo calcula el `bff` (ADR 20).

**Mecanismo de rupturas intencionales (D4):**
- `rompimientos/v0.1.0-tracer.4.yaml`: allowlist por versión; cada ruptura lista
  la operación/mensaje afectado y su fuente (ADR/DEC).
- `tools/breaking-gate`: tool Go que lee la salida de oasdiff/buf y autoriza SOLO
  las rupturas declaradas en `rompimientos/${VERSION}.yaml`, y SOLO mientras
  `VERSION` sea esa versión; cualquier ruptura no listada sigue fallando.
- `scripts/breaking-openapi.sh` y el nuevo `scripts/breaking-eventos.sh` (al que
  apunta `make breaking` y la invocación de `buf breaking` en CI) pasan su veredicto
  por el gate.
- `scripts/test-breaking-gate.sh` (target `make test-breaking-gate`, paso nuevo en
  CI): prueba el propio mecanismo — una ruptura no listada falla, y la allowlist
  no aplica a otra versión.

**Versión:** `VERSION`, `package.json` y el `info.version` de los seis specs
suben a `0.1.0-tracer.4` (los specs venían rezagados en `tracer.2`).

**Verificación (gate local, salida real):** `make lint`, `check-estados` (13
estados), `check-registro` (12 tipos), `check-tags` (9 paquetes), `breaking` y
`breaking-openapi` (rupturas declaradas aceptadas; el resto compatible),
`test-breaking-gate` y `contract-tests` pasan. El consumidor limpio del gate se
salta sin tag publicado (R5); se verificó de verdad con un consumidor Go por
`replace` al árbol (`.scratch/tracer-4-ola-1/`) que EJECUTA y afirma:
`PuedeTransicionar(ASIGNADO, EN_TRANSITO)` true, la guarda de aptitud ausente, la
forma nueva de asignación/roster/eventos, y el mapeo roles/Audiencia (ocho roles,
`cliente` externo). `check-reproducible` sólo pasará cuando el Lead commitee
fuentes y artefactos juntos; el codegen es determinista (regenerar dos veces da
los mismos bytes).

**Archivos modificados:**
- `VERSION`, `packages/api-client-ts/package.json`
- `contracts/estados/viaje.estados.yaml`
- `contracts/events/ai27/eventos/v1/viaje.proto`
- `contracts/events/INVENTARIO.md` (etiqueta de versión del encabezado)
- `contracts/openapi/catalogos.yaml`, `contracts/openapi/operacion.yaml`
- `contracts/openapi/{_comunes,bff,identidad,reportes}.yaml` (sólo `info.version`)
- `rompimientos/v0.1.0-tracer.4.yaml` (nuevo)
- `tools/breaking-gate/` (nuevo)
- `scripts/breaking-openapi.sh`, `scripts/breaking-eventos.sh` (nuevo),
  `scripts/test-breaking-gate.sh` (nuevo)
- `Makefile`, `.github/workflows/contracts.yml`
- `packages/api-client-go/`, `packages/api-client-ts/src/` (artefactos regenerados)

## 2026:10:06 12:55

**Resumen:** Se reemplazó la plantilla de Pull Request (venía copiada del frontend) por una adaptada al rol de este repo como fuente de contratos.

**Cambios:**
- Se reescribió `.github/pull_request_template.md`: la anterior era la del portal-cliente (comandos pnpm, invariantes de UI), que no aplica. La nueva es específica de `pf-pkg-contracts`: invariantes del freeze (ADR 25), breaking checks de OpenAPI y eventos, codegen reproducible, contract tests que ejecutan, conservación de sustantivos de dominio en español, y manifiesto con tag/SHA/checksums en los releases.

**Archivos modificados:**
- `.github/pull_request_template.md`

## 2026:10:05 22:40

**Resumen:** Se ejecutaron las **pruebas negativas** que exige la definición de
listo del handoff y dos de ellas no estaban documentadas. Las tres pasan. Una
sorprendió: quitar un campo `required` de un cuerpo de petición **no** es un
cambio incompatible, y el gate acierta al no marcarlo.

**Verificación (pruebas negativas, con salida real):**
- `make breaking-openapi` — se agrega `notas` como campo **nuevo y `required`**
  a `CrearViajeEntrada` (`bff.yaml`), que sigue siendo un spec válido para
  `lint-openapi`. Resultado: `1 changes: 1 error, 0 warning, 0 info`,
  `error [new-required-request-property]`, y el script sale **2** (rojo). Al
  revertir: `OK: OpenAPI compatible con v0.1.0-tracer.3`. El invariante «un
  cambio incompatible de OpenAPI rompe CI» está comprobado, no supuesto.
- El caso inverso **no** es incompatible: quitar `destinos` de
  `required: [origen, destinos]` deja el gate en verde, y está bien que sea así.
  `required` en una petición significa «el cliente debe enviar esto»; relajarlo
  amplía lo que el servidor acepta, así que un cliente viejo sigue funcionando.
  Escribir el test al revés habría producido una falsa alarma y, peor, la
  impresión de que el gate estaba probado cuando sólo se había probado que
  dispara ante el caso fácil.
- `make check-reproducible` — se edita a mano `roles.gen.go`
  (`"cliente"` → `"CLIENTE"`). Resultado: `check-arbol-limpio` lo detecta con
  `1 file changed` y sale **2** antes de regenerar, con el mensaje de que los
  `*.gen.*` no se editan a mano. Al revertir: `OK: los artefactos generados
  coinciden con la fuente`.

## 2026:10:05 22:05

**Resumen:** `v0.1.0-tracer.3` sustituye a `v0.1.0-tracer.2`, que se retira.
`tracer.2` se publicó con `roles.EsInterno()` y su gemelo TS `esInterno`
devolviendo la semántica de `Audiencia` invertida (`cliente` dado como interno,
`jefe_operativo` como externo). El defecto de `tracer.2` es el mismo tipo de
problema que el de `tracer.1`: un artefacto publicado que un consumidor resuelve
y en el que no puede confiar.

**Cambios:**
- Versión bumpeada a `v0.1.0-tracer.3` en `VERSION` y `package.json`.
- Se retira `v0.1.0-tracer.2`: se borran su release, sus dos tags y su versión
  en el registry npm, de la misma forma en que se retiró `tracer.1`. No queda
  ningún artefacto defectuoso resoluble.
- Se corrige `tools/gen-roles` (ver la entrada anterior): `esInterno` se genera
  como `r != RolCliente` y la generación falla si el enum deja de contener
  `cliente`.
- `scripts/contract-tests.sh` ejecuta al consumidor limpio (`go run`) en vez de
  sólo compilarlo, con la aserción sobre el mapeo a `Audiencia` para los ocho
  roles. Ese par de cambios es lo que hace imposible que `tracer.3` repita el
  defecto de `tracer.2` sin que CI se ponga rojo.
- `.github/workflows/contracts.yml`: el gate de versión compara también
  `VERSION` con la versión de `packages/api-client-ts/package.json`. Eran dos
  fuentes de verdad escritas a mano; si la segunda se quedaba atrás, el tarball
  publicado llevaría un número distinto al del release.

**Hueco conocido:** `scripts/check-ts-exports.sh` empaqueta el tarball y resuelve
cada subpath de `exports`, pero no ejecuta el TypeScript. No hay, por tanto,
ninguna comprobación de *valor* en TS: que `esInterno` devuelva lo correcto no lo
verifica nadie. El bug invertido venía de un helper único del generador y la
aserción de Go lo cubre, pero el TS se renderiza por separado y eso no lo
garantiza a futuro. Cerrarlo requiere un runner de TS (`node` sobre el tarball
instalado) y merece su propio paso, no un fix de correctness.

## 2026:10:05 21:40

**Resumen:** La prerelease `v0.1.0-tracer.2` se publicó y quedó revealed un
defecto en ella: `roles.EsInterno()` (y su gemelo TS `esInterno`) devolvían la
semántica de `Audiencia` invertida. Se corrige el generador y, sobre todo, se
arregla el fallo del arnés que dejó pasar el defecto: los contract tests
compilaban al consumidor limpio pero no lo ejecutaban, así que todas sus
aserciones eran código muerto.

**Cambios:**
- `tools/gen-roles`: `esInterno` se generaba como `r != <primer rol que NO es
  cliente>`, que con este enum es `jefe_operativo`. Decía "el único externo es
  `cliente`" y hacía justo lo contrario: `EsInterno("cliente")` era `true` y
  `EsInterno("jefe_operativo")` era `false`. Los otros seis roles salían bien por
  casualidad, que es lo que lo hizo pasar desapercibido. Ahora se niega a
  `RolCliente`, y si el enum dejara de contener `cliente` la generación **falla**
  en vez de emitir un mapeo inventado.
- `scripts/contract-tests.sh`: el consumidor limpio pasa de `go build` a `go run`.
  Compilar sólo prueba que los símbolos existen; las aserciones sobre valores
  (mapeo a `Audiencia`, enum de estados, registro de eventos) nunca se
  ejecutaban. Es el mismo fallo de forma que el de `check-ts-exports`: una
  comprobación que no puede fallar no es una comprobación.
- `scripts/contract-tests.sh`: se agrega la aserción que faltaba sobre el mapeo a
  `Audiencia`, para los ocho roles y no sólo para `cliente`.
- `.github/workflows/contracts.yml`: `check-tags` compara el tag prefijado del
  módulo Go con el commit **_solo_ durante la publicación
  (`--verificar-tag-go`), en un paso nuevo justo después de crearlo. Antes se
  comparaba siempre, y en el job `verificar` el tag era el de la release
  anterior, que por definición apunta a otro commit: en cuanto hubo una release
  previa —el estado normal del repo— CI rompía con un mensaje que además
  describía el defecto de `tracer.1`, que no era lo que pasaba.
- `.github/workflows/contracts.yml`: se fija la identidad de git antes de crear
  el tag del módulo Go, se lee el tag existente con `git ls-remote` en vez de
  recrearlo (prereleases son inmutables), y la release se marca `prerelease`
  cuando la versión lleva sufijo. Sin esto la primera publicación salió como
  release estable, que es la señal equivocada donde un humano decide si
  consumirla.
- `scripts/contract-tests.sh`: el módulo es privado, así que el `go get` del
  consumidor necesita credenciales y el runner no tiene ninguna. Se reescriben
  las URLs con una config de git efímera (`insteadOf`) en vez de `.netrc`, que
  go no lee: el fallo era `could not read Username for 'https://github.com'`.

**Verificación:** con la corrección aplicada, `go run` del consumidor limpio
falla contra el tag publicado con `panic: EsInterno("cliente") = true; el
contrato dice false`. Es la evidencia de que el defecto era real y de que la
comprobación nueva lo detecta.

## 2026:10:05 18:56

**Resumen:** Se corrigieron los `exports` del paquete npm, que declaraban
subpaths que no resolvían, y se agregó la comprobación que lo detecta. Se
preparó además la prerelease `v0.1.0-tracer.2`, que sustituye a `tracer.1`
(retirada). El defecto de `tracer.1` fue que su tag resolvía el módulo Go sin
llevar dentro los clientes generados: no había nada importable. Aquí los
artefactos se versionan, y el pipeline verifica que el árbol etiquetado esté
completo y que el manifiesto congele sus bytes antes de publicar.

**Cambios:**
- `packages/api-client-ts/package.json`: los patrones `./openapi/*` y
  `./eventos/*` apuntaban a `./src/openapi/*.ts` y `./src/eventos/*`. Los
  archivos reales se llaman `*.gen.ts`, así que `@ai27-tech/contracts/openapi/bff`
  devolvía `MODULE_NOT_FOUND` en el consumidor. Ahora son `./src/openapi/*.gen.ts`
  y `./src/eventos/*.ts`.
- Se agregó `scripts/check-ts-exports.sh`: empaqueta el tarball que se
  publicaría, lo instala en un proyecto limpio y resuelve cada subpath declarado
  en `exports`. `tsc --noEmit` no lo detectaba, porque nunca resuelve subpaths.
  Probado en positivo y en negativo (con el patrón anterior, que falla).
- Los clientes generados de Go y TypeScript ahora se commitean (decisión de owner,
  opción (a)) y `.gitignore` deja de ignorarlos. Congelar el contrato exige que lo
  que el consumidor resuelve por versión esté en el tag.
- Se agregó el registro de tipos de evento `contracts/events/registro.tipos.yaml`,
  su generador `tools/gen-registro` (Go y TS) y el verificador
  `tools/check-registro`, que contrasta registro, `.proto` e `INVENTARIO.md`.
- Se agregó el enum canónico de roles (ocho roles) y su generador
  `tools/gen-roles`, con validador en runtime: un rol desconocido se rechaza en
  servidor, nunca se degrada a un permiso por defecto.
- `check-reproducible` ahora compara cada artefacto contra su blob en `HEAD` en
  vez de contra el árbol de trabajo. Antes sólo veía lo que la generación dejaba:
  editar a mano un `*.gen.go` y commitearlo pasaba el chequeo, porque regenerar lo
  sobrescribía antes de comparar. Se agrega `check-arbol-limpio` para el caso
  simétrico (editar sin commitear).
- Se agregó `scripts/breaking-openapi.sh` (oasdiff contra el último tag de tracer
  publicado, no contra una rama: una rama no es evidencia de freeze) y `oasdiff`
  quedó anclado en `tools/oasdiff`, como `oapi-codegen` en `tools/openapi-codegen`.
  Antes el script invocaba `npx oasdiff@v1.11.7`, un paquete npm que no existe.
- Se agregó `scripts/check-tags.sh`: el árbol etiquetado debe traer los nueve
  paquetes del módulo Go. Convierte en fallo de CI el defecto de `tracer.1`.
- Se agregó `scripts/contract-tests.sh`: compila un consumidor limpio que importa
  y usa los nueve paquetes contra el tag publicado, más la consistencia del
  registro. Corre en el job `publicar` después de crear el tag prefijado y antes
  de publicar en npm (invariante 7 de ADR 25).
- El manifiesto ahora congela fuentes **y** artefactos (tres clases de checksums,
  incluyendo `package.json` y `tsconfig.json` del paquete npm) y se valida a sí
  mismo como JSON. Se agregó `scripts/verificar-manifiesto.sh`, que comprueba
  coherencia (cada archivo listado hashea igual), completitud (cada archivo del
  alcance está listado, en ambos sentidos) e identidad (tag/SHA contra `HEAD`).
- El job `verificar` ganó breaking de OpenAPI, consistencia del registro y
  contenido del árbol etiquetado; `publicar` verifica el manifiesto y corre los
  contract tests antes de publicar en npm.
- El `README.md` documenta la estructura real, los nuevos objetivos de `make`, el
  orden del pipeline y el estado del freeze.

**Archivos modificados:**
- `.github/workflows/contracts.yml`
- `.gitignore`
- `Makefile`
- `VERSION`
- `README.md`
- `contracts/events/INVENTARIO.md`
- `contracts/events/registro.tipos.yaml` (nuevo)
- `contracts/openapi/_comunes.yaml`
- `contracts/openapi/bff.yaml`
- `contracts/openapi/catalogos.yaml`
- `contracts/openapi/identidad.yaml`
- `contracts/openapi/operacion.yaml`
- `contracts/openapi/reportes.yaml`
- `packages/api-client-go/` (clientes, eventos, estados, roles y registro generados)
- `packages/api-client-go/doc.go`
- `packages/api-client-go/go.mod`
- `packages/api-client-ts/package.json`
- `packages/api-client-ts/package-lock.json`
- `packages/api-client-ts/src/index.ts`
- `packages/api-client-ts/src/` (tipos OpenAPI, eventos, estados, roles y registro)
- `scripts/breaking-openapi.sh` (nuevo)
- `scripts/check-reproducible.sh` (nuevo)
- `scripts/check-tags.sh` (nuevo)
- `scripts/check-ts-exports.sh` (nuevo)
- `scripts/contract-tests.sh` (nuevo)
- `scripts/generar.sh`
- `scripts/manifiesto.sh`
- `scripts/verificar-manifiesto.sh` (nuevo)
- `tools/check-registro/` (nuevo)
- `tools/gen-registro/` (nuevo)
- `tools/gen-roles/` (nuevo)
- `tools/oasdiff/` (nuevo)

## 2026:09:15 14:03

**Resumen:** Se corrigió la publicación del módulo Go, que no se podía resolver
con `go get` porque vive en el subdirectorio `packages/api-client-go/` y el tag
de release `v0.1.0-tracer.1` sólo resuelve el módulo raíz (inexistente).

**Cambios:**
- El job `publicar` ahora crea y empuja, junto al release, el tag prefijado por
  subdirectorio que Go exige para un módulo anidado
  (`packages/api-client-go/vX.Y.Z`), apuntando al mismo commit del release. Es
  idempotente: no recrea el tag si ya existe.
- Se documentó en el `README.md` el esquema de dos tags por release (el limpio
  `vX.Y.Z` para npm/Release/manifiesto y el prefijado para el módulo Go) y se
  aclaró que en `go get` la versión se escribe sin prefijo.

**Archivos modificados:**
- `.github/workflows/contracts.yml`
- `README.md`

## 2026:09:15 13:35

**Resumen:** Se corrigió el paso de publicación de npm del job `publicar`, que
fallaba con `You must specify a tag using --tag when publishing a prerelease
version` al publicar la versión prerelease `0.1.0-tracer.1`.

**Cambios:**
- El paso ahora deriva un dist-tag de npm del sufijo de prerelease de la versión
  (`0.1.0-tracer.1` → `--tag tracer`) y publica con `npm publish --tag`; una
  versión estable (sin sufijo) se publica bajo `latest`. npm no permite publicar
  una prerelease bajo `latest`, de ahí el error.

**Archivos modificados:**
- `.github/workflows/contracts.yml`

## 2026:09:15 12:59

**Resumen:** Se adoptó el formato de `CHANGELOG.md` definido por la regla de
steering `.kiro/steering/changelog.md` y se convirtieron todas las entradas
existentes a ese formato.

**Cambios:**
- Se reescribieron las entradas al formato `## yyyy:mm:dd hora:minuto` con los
  campos `Resumen`, `Cambios` y `Archivos modificados`.
- Se eliminó el envoltorio `## [Sin publicar]` y la referencia al archivo de
  steering anterior (`registro-de-cambios.md`), que fue reemplazado.

**Archivos modificados:**
- `CHANGELOG.md`

## 2026:09:15 12:54

**Resumen:** Se agregó al `README.md` la sección «Cómo funciona» con un diagrama
del flujo del repositorio.

**Cambios:**
- Se documentó el flujo de fuentes contractuales (estados, OpenAPI, eventos) a
  la generación reproducible (gen-estados, redocly bundle +
  oapi-codegen/openapi-typescript, buf generate), la verificación (check-estados,
  lint, breaking, reproducibilidad) y el consumo por versión exacta, con un
  diagrama Mermaid y una explicación paso a paso.
- Se explicó qué se versiona y qué se regenera.

**Archivos modificados:**
- `README.md`

## 2026:09:15 12:53

**Resumen:** Se corrigieron los errores de `redocly lint` que hacían fallar la
canalización de CI en los specs de OpenAPI.

**Cambios:**
- Se cambió `examples` (palabra de OpenAPI 3.1) por `example` en `_comunes.yaml`.
- Se reescribió el patrón inválido en 3.0.x `allOf: [$ref] + nullable: true`: los
  `$ref` a tipos string (`Id`, `Cursor`, `MarcaTiempo`) pasan a `type: string` +
  `nullable: true` con su `format`; los `$ref` a objetos (`AsignacionEntrada`,
  `Eta`) se referencian directamente por ser campos opcionales (ausente = sin
  valor).
- `make lint-openapi` ahora hace `redocly bundle` antes de lintear, de modo que
  el `securityScheme` `bearerCognito` de `_comunes.yaml` queda resuelto y la
  regla `security-defined` no falla al lintear archivos sueltos.
- Se agregó `redocly.yaml` que apaga `info-license` (la licencia vive en
  `package.json`, no por documento).

**Archivos modificados:**
- `contracts/openapi/_comunes.yaml`
- `contracts/openapi/identidad.yaml`
- `contracts/openapi/catalogos.yaml`
- `contracts/openapi/operacion.yaml`
- `contracts/openapi/bff.yaml`
- `contracts/openapi/reportes.yaml`
- `redocly.yaml`
- `Makefile`

## 2026:09:15 12:34

**Resumen:** Se corrigió el paso de breaking check de `buf` en la canalización,
que fallaba en GitHub Actions por intentar clonar el repositorio por HTTPS sin
credenciales.

**Cambios:**
- El paso obtiene la rama base con `git fetch` y compara contra el ref local
  (`buf breaking --against '.git#ref=FETCH_HEAD'`) en lugar del clone HTTPS que
  producía `could not read Username ... exit status 128`.
- Se omite el breaking check de forma explícita cuando `pf-contracts-m` todavía
  no tiene contratos publicados (no hay línea base en el primer release).

**Archivos modificados:**
- `.github/workflows/contracts.yml`

## 2026:09:15 12:33

**Resumen:** Se incorporó una regla de steering de registro de cambios e idioma
de la documentación (posteriormente reemplazada por `.kiro/steering/changelog.md`).

**Cambios:**
- Se agregó la regla obligatoria de `CHANGELOG.md` y de idioma como archivo de
  steering siempre activo, adaptada a este repositorio (Go + TypeScript).
- Se reestructuró `CHANGELOG.md` al formato de entradas fechadas que definía esa
  regla.

**Archivos modificados:**
- `.kiro/steering/registro-de-cambios.md`
- `CHANGELOG.md`

## 2026:09:15 12:06

**Resumen:** Contenido inicial del repositorio, que estaba vacío (hallazgo F-01).
Congela el tracer vertical hacia la versión objetivo `v0.1.0-tracer.1` (ADR 25);
la release la publica CI sobre el tag.

**Cambios:**
- Se agregó la máquina de estados del `viaje` como dato (enum canónico de ADR 19:
  13 estados de progreso, estados V2 inalcanzables, alias histórico
  `EN_BASE_CLIENTE`, condiciones ortogonales `INCIDENCIA`/`SIN_SENAL` y el grafo
  multi-parada).
- Se agregaron los specs OpenAPI del tracer en 3.0.3 (por compatibilidad con
  `oapi-codegen`), congelando la doble superficie de sesión (`bff`
  `/api/v1/sesion` singular pública e `identidad` `/api/v1/sesiones` plural
  interna).
- Se agregaron los eventos Protobuf con su inventario productor → evento →
  consumidores → agregado → clave de orden → sensibilidad.
- Se agregó la generación reproducible de Go y TypeScript y la canalización de CI.

**Archivos modificados:**
- `contracts/estados/viaje.estados.yaml`
- `contracts/openapi/*.yaml`
- `contracts/events/ai27/eventos/v1/*.proto`
- `contracts/events/INVENTARIO.md`
- `tools/gen-estados/`, `tools/check-estados/`, `tools/openapi-codegen/`
- `scripts/generar.sh`, `scripts/manifiesto.sh`
- `buf.yaml`, `buf.gen.yaml`, `codegen/oapi-codegen.base.yaml`, `Makefile`
- `packages/api-client-go/`, `packages/api-client-ts/`
- `.github/workflows/contracts.yml`
- `README.md`, `VERSION`, `.gitignore`
