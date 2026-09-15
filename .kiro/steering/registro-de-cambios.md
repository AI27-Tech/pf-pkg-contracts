---
inclusion: always
---

# Regla obligatoria: registro de cambios y idioma de la documentación

Este documento es una regla permanente del repositorio `pf-pkg-contracts`.
Aplica a **todo** cambio realizado en él, sin excepción y sin necesidad de que la
persona usuaria lo recuerde o lo solicite.

Es la misma regla vigente en los demás repositorios de la plataforma AI27,
adaptada a las rutas y al stack de este repositorio (Go + TypeScript, contratos
generados). Las convenciones de los repositorios se mantienen alineadas de forma
deliberada.

## 1. Idioma

- **Toda** la documentación del repositorio se redacta en **español**: archivos
  Markdown, comentarios de código, docstrings, mensajes de error visibles,
  descripciones de esquemas (OpenAPI, Protobuf, estados) y cualquier texto que
  explique o describa algo.
- La conversación con la persona usuaria puede ocurrir en inglés; eso **no**
  cambia la regla anterior. Los artefactos que quedan en el repositorio van en
  español.
- Se conservan en su idioma original los identificadores de código, nombres de
  librerías, claves de configuración y términos técnicos sin traducción
  establecida (por ejemplo `handler`, `endpoint`, `token`, `scope`, `bundle`).
- **Los sustantivos de dominio se conservan en español** también como
  identificadores, rutas de API, nombres de evento, esquemas y tokens de estado
  (`viaje`, `sesion`, `catalogos`, `operacion`, `bitacora`, `asignacion`,
  `custodio`, `incidencia`, `reportes`), conforme a la convención de nombres de
  la plataforma (ADR 22 / DEC-024). Esta regla de idioma no la contradice: la
  refuerza.

## 2. Cuándo registrar una entrada

Después de completar cualquier tarea que **modifique, cree o elimine archivos**
en este repositorio, hay que agregar una entrada en `CHANGELOG.md` **antes** de
entregar el resumen final a la persona usuaria. La entrada forma parte de la
tarea, no es un paso opcional posterior.

- **Una entrada por tarea o solicitud completada**, no una por archivo ni una
  por edición individual.
- Se registran **todos** los tipos de cambio: fuentes contractuales
  (`contracts/openapi/`, `contracts/events/`, `contracts/estados/`),
  herramientas de generación (`tools/`, `scripts/`), configuración de generación
  y lint (`buf.yaml`, `buf.gen.yaml`, `codegen/`), scaffolding de los paquetes
  publicados (`packages/api-client-go/`, `packages/api-client-ts/`),
  infraestructura y CI (`.github/workflows/`, `Dockerfile` si existiera),
  documentación (`README.md`, `docs/`) y esta misma carpeta de steering
  (`.kiro/steering/`).
- **No** se registra: una edición que solo toque `CHANGELOG.md` (no genera una
  entrada propia adicional), ni las tareas de solo lectura, consulta,
  explicación o diagnóstico que no modifican archivos.
- **No** se registran los artefactos generados que el repositorio no versiona
  (los clientes de OpenAPI y los tipos de evento generados, ignorados por
  `.gitignore`): su cambio se describe a través del cambio en su **fuente**
  (el spec, el `.proto` o la fuente de estados) y en la herramienta que los
  genera. La rebanada de estados generada que **sí** se versiona
  (`packages/**/estados/`) se menciona cuando su fuente cambia.

## 3. Cómo obtener la fecha y la hora

La marca de tiempo **nunca se inventa ni se deduce de memoria**. Se obtiene
ejecutando el comando del sistema:

```bash
TZ=America/Mexico_City date "+%Y-%m-%d %H:%M:%S"
```

Toda marca de tiempo del `CHANGELOG.md` está expresada en la zona horaria
`America/Mexico_City` y así se indica en el encabezado de la entrada.

## 4. Dónde y cómo se inserta la entrada

- La entrada se inserta **al inicio** de la sección `## [Sin publicar]`, de modo
  que la más reciente quede siempre primero.
- **Nunca** se editan, reescriben, reordenan ni eliminan entradas ya
  existentes, ni las secciones de versiones publicadas. El archivo es un
  registro acumulativo.
- El campo `Tipo` usa exactamente uno de estos valores: `Añadido`, `Cambiado`,
  `Obsoleto`, `Eliminado`, `Corregido`, `Seguridad`.
- El campo `Resumen` explica **qué** cambió y **por qué**, en prosa clara y
  suficiente para entender el cambio sin abrir el diff. No basta con repetir el
  nombre de los archivos.
- El campo `Archivos afectados` lista cada ruta modificada con una nota breve
  de lo que cambió en ella.

### Plantilla

```markdown
### AAAA-MM-DD HH:MM:SS (America/Mexico_City)

- **Tipo:** Añadido
- **Alcance:** contratos
- **Resumen:** descripción de qué cambió y por qué.
- **Archivos afectados:**
  - `ruta/al/archivo.yaml` — qué se modificó.
```

### Ejemplo completo

```markdown
### 2026-09-15 12:33:11 (America/Mexico_City)

- **Tipo:** Corregido
- **Alcance:** CI
- **Resumen:** se corrigió el paso de breaking check de `buf`, que clonaba el
  repositorio por HTTPS y fallaba en Actions con `could not read Username`.
  Ahora compara contra el ref local de `pf-contracts-m` y se omite cuando aún no
  existe una línea base publicada.
- **Archivos afectados:**
  - `.github/workflows/contracts.yml` — el paso obtiene la rama por `git fetch`
    y usa `buf breaking --against '.git#ref=FETCH_HEAD'` en lugar del clone HTTPS.
```

## 5. Verificación

El campo `Alcance` de la plantilla usa términos de este repositorio, por
ejemplo: `contratos`, `estados`, `eventos`, `openapi`, `herramientas`, `CI`,
`documentación`, `paquetes`.

Tras editar `CHANGELOG.md`, se comprueba de forma manual que la entrada respete
la estructura: título del archivo, una única sección `## [Sin publicar]`, orden
cronológico inverso (la más reciente primero), campos obligatorios presentes y
`Tipo` dentro de los valores admitidos.

Este repositorio todavía **no** tiene un validador estructural automatizado del
`CHANGELOG.md` (a diferencia del validador `pytest` de los servicios en Python).
Mientras no exista, la entrada se redacta igualmente conforme a la plantilla de
la sección 4. Cuando se agregue el validador, se incorporará a la canalización
de integración continua (`.github/workflows/contracts.yml`) y se documentará
aquí su comando.

## 6. Publicación de versiones (solo a petición explícita)

La consolidación de `Sin publicar` en una versión publicada **nunca** se hace
por iniciativa propia: solo cuando la persona usuaria lo pida de forma
explícita. Este repositorio usa **prereleases de tracer** con Versionado
Semántico (por ejemplo `v0.1.0-tracer.1`, `v0.1.0-tracer.2`), y la publicación
real de la versión la ejecuta CI al empujar el tag correspondiente (ADR 25). El
procedimiento del `CHANGELOG.md` es:

1. Revisar las entradas acumuladas en `## [Sin publicar]` y **proponer** el
   incremento de versión, justificándolo con los tipos de cambio presentes:
   - `Eliminado` o cambios incompatibles → incremento **mayor**, o el siguiente
     `-tracer.N` cuando todavía se congela el tracer.
   - `Añadido` → incremento **menor**.
   - Solo `Corregido`, `Seguridad` u `Obsoleto` → incremento de **parche** o el
     siguiente `-tracer.N`.

   Recordar la regla de evolución del contrato: agregar es aditivo; quitar o
   renumerar exige un release de gracia (expand/contract). Una corrección
   posterior **no** modifica un tag ya publicado (por ejemplo `tracer.1`):
   publica otra prerelease (`tracer.2`).
2. **Confirmar** el número de versión con la persona usuaria antes de escribir
   nada.
3. Obtener la fecha de publicación con
   `TZ=America/Mexico_City date "+%Y-%m-%d"`.
4. Crear la sección `## [x.y.z(-tracer.N)] - AAAA-MM-DD` inmediatamente debajo de
   `## [Sin publicar]`, con subsecciones `###` por tipo de cambio (`Añadido`,
   `Cambiado`, `Obsoleto`, `Eliminado`, `Corregido`, `Seguridad`) y solo las que
   apliquen.
5. Trasladar cada entrada acumulada a la subsección de su tipo, conservando su
   marca de tiempo original como prefijo del elemento:
   `` - `AAAA-MM-DD HH:MM:SS` — resumen del cambio. ``
6. Dejar `## [Sin publicar]` **vacía**, lista para el siguiente cambio.
7. Actualizar el archivo `VERSION` (y, cuando corresponda, la `version` del
   paquete npm en `packages/api-client-ts/package.json`) al mismo número de
   versión, de modo que la fuente única de versión, el tag y los artefactos
   publicados coincidan. El módulo Go se versiona por el propio tag Git.
8. Verificar la estructura del `CHANGELOG.md` (sección 5) y, cuando existan,
   ejecutar las verificaciones de contrato del repositorio (`make verify`).

La actualización de `VERSION` es parte de este procedimiento; fuera de él la
versión no se toca.

## 7. Límites

- **No** crear commits, tags ni publicar versiones por iniciativa propia: solo
  cuando la persona usuaria lo pida explícitamente. En particular, el tag que
  congela un release (por ejemplo `v0.1.0-tracer.1`) lo produce la canalización
  de CI sobre el tag empujado, no se crea a mano.
- **No** editar entradas ya publicadas ni las secciones de versiones cerradas.
