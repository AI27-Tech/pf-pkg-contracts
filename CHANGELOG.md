# Changelog — pf-pkg-contracts

Registro acumulativo de cambios. Zona horaria de las marcas de tiempo:
`America/Mexico_City`. Versionado Semántico con prereleases de tracer
(`v0.1.0-tracer.N`). El formato de las entradas y el procedimiento de
publicación están definidos en `.kiro/steering/registro-de-cambios.md`.

## [Sin publicar]

### 2026-09-15 12:34:43 (America/Mexico_City)

- **Tipo:** Corregido
- **Alcance:** CI
- **Resumen:** se corrigió el paso de breaking check de `buf` en la canalización,
  que clonaba el repositorio por HTTPS y fallaba en GitHub Actions con
  `could not read Username ... exit status 128` por falta de credenciales. Ahora
  el paso obtiene la rama base con `git fetch` y compara contra el ref local
  (`buf breaking --against '.git#ref=FETCH_HEAD'`); además se omite de forma
  explícita cuando `pf-contracts-m` todavía no tiene contratos publicados (no hay
  línea base en el primer release).
- **Archivos afectados:**
  - `.github/workflows/contracts.yml` — el paso «Breaking check de eventos»
    reemplaza el clone HTTPS por fetch + ref local y agrega la guarda de
    ausencia de línea base.

### 2026-09-15 12:33:11 (America/Mexico_City)

- **Tipo:** Añadido
- **Alcance:** documentación
- **Resumen:** se incorporó la regla obligatoria de registro de cambios e idioma
  de la documentación como archivo de steering siempre activo, adaptada a este
  repositorio (Go + TypeScript, rutas de `contracts/`, `packages/`, `tools/` y
  `.github/workflows/`; sin validador `pytest` todavía). Alinea la disciplina de
  `CHANGELOG.md` y la política de español con la del resto de los repositorios
  de la plataforma. Como parte del mismo cambio, se reescribió `CHANGELOG.md` al
  formato de entradas fechadas que la regla define, conservando el contenido de
  la entrada inicial.
- **Archivos afectados:**
  - `.kiro/steering/registro-de-cambios.md` — regla nueva (`inclusion: always`).
  - `CHANGELOG.md` — reestructurado al formato de entradas fechadas bajo
    `## [Sin publicar]`.

### 2026-09-15 12:06:03 (America/Mexico_City)

- **Tipo:** Añadido
- **Alcance:** contratos, eventos, estados, herramientas, paquetes, CI
- **Resumen:** contenido inicial del repositorio, que estaba vacío (hallazgo
  F-01). Congela el **tracer vertical** hacia la versión objetivo
  `v0.1.0-tracer.1` (ADR 25); la release la publica CI sobre el tag, este cambio
  deja el árbol listo. Incluye la máquina de estados del `viaje` como dato
  (enum canónico de ADR 19: 13 estados de progreso, estados V2 inalcanzables,
  alias histórico `EN_BASE_CLIENTE`, condiciones ortogonales `INCIDENCIA`/
  `SIN_SENAL` y el grafo multi-parada); los specs OpenAPI del tracer en 3.0.3
  (por compatibilidad con `oapi-codegen`), congelando la doble superficie de
  sesión (`bff` `/api/v1/sesion` singular pública e `identidad`
  `/api/v1/sesiones` plural interna); los eventos Protobuf con su inventario
  productor → evento → consumidores → agregado → clave de orden → sensibilidad;
  la generación reproducible de Go y TypeScript; y la canalización de CI.
- **Archivos afectados:**
  - `contracts/estados/viaje.estados.yaml` — fuente única de la máquina de estados.
  - `contracts/openapi/*.yaml` — specs de `identidad`, `catalogos`, `operacion`,
    `bff`, `reportes` y `_comunes.yaml`.
  - `contracts/events/ai27/eventos/v1/*.proto`, `contracts/events/INVENTARIO.md`
    — eventos de dominio e inventario contractual.
  - `tools/gen-estados/`, `tools/check-estados/`, `tools/openapi-codegen/` —
    generación de estados, verificación estados↔OpenAPI y fijación del generador.
  - `scripts/generar.sh`, `scripts/manifiesto.sh` — codegen reproducible y
    manifiesto de release.
  - `buf.yaml`, `buf.gen.yaml`, `codegen/oapi-codegen.base.yaml`, `Makefile` —
    configuración de lint y generación.
  - `packages/api-client-go/`, `packages/api-client-ts/` — scaffolding de los
    paquetes publicados y la rebanada de estados generada.
  - `.github/workflows/contracts.yml` — verificación en push/PR y publicación en
    tag `v*-tracer.*`.
  - `README.md`, `VERSION`, `.gitignore` — documentación, versión objetivo y
    exclusión de artefactos generados.
