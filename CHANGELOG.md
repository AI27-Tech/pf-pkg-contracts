# Changelog — pf-pkg-contracts

Registro de cambios del repositorio. El formato y las reglas están definidos en
`.kiro/steering/changelog.md`. Entradas en español, las más recientes primero.

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
