# Changelog — pf-pkg-contracts

Formato basado en Keep a Changelog; versionado SemVer con prereleases de tracer.

## [No publicado]

### Agregado — contenido inicial del paquete contractual del tracer (E0-T2)

Primer contenido del repositorio, que hasta ahora estaba vacío (hallazgo F-01).
Congela el **tracer vertical** hacia la versión objetivo `v0.1.0-tracer.1`
(ADR 25). La versión se publica cuando CI corre sobre su tag; este cambio deja
el árbol listo, no crea la release.

- **Máquina de estados como dato** (`contracts/estados/viaje.estados.yaml`):
  enum canónico del `viaje` (ADR 19) con 13 estados de progreso, estados V2
  inalcanzables declarados, alias histórico `EN_BASE_CLIENTE`, condiciones
  ortogonales `INCIDENCIA`/`SIN_SENAL`, y el grafo de transiciones multi-parada.
- **OpenAPI del tracer** (`contracts/openapi/`): `identidad`, `catalogos`,
  `operacion`, `bff`, `reportes` y `_comunes.yaml`. Se congela la doble
  superficie de sesión: `bff` `/api/v1/sesion` (singular, pública) e `identidad`
  `/api/v1/sesiones` (plural, interna).
- **Eventos Protobuf** (`contracts/events/`): sobre de dominio, familia
  `viaje.*`, `sesion.revocada`, `catalogo.actualizado`, e `INVENTARIO.md` con la
  tabla productor → evento → consumidores → agregado → clave de orden →
  sensibilidad. El tracer usa sólo la superficie amplia.
- **Generación reproducible** Go y TypeScript: `tools/gen-estados`,
  `scripts/generar.sh` (redocly bundle + oapi-codegen + openapi-typescript + buf
  generate), y `tools/check-estados` para la equivalencia estados↔OpenAPI.
- **Paquetes**: módulo Go `.../packages/api-client-go` y paquete npm
  `@ai27-tech/contracts`.
- **CI** (`.github/workflows/contracts.yml`): verificación en push/PR y
  publicación coordinada en tag `v*-tracer.*` con manifiesto (tag/SHA/checksums).
