<!--
Plantilla de Pull Request de pf-pkg-contracts (la fuente única de contratos de
AI27: OpenAPI + eventos + estados, de la que se generan los clientes Go y TS).
Los contratos son el artefacto, no el repositorio. Rellena lo que aplique.
Autoridad: ADR 25 (paquete contractual del tracer) y sus invariantes.
-->

## Resumen

<!-- Qué cambia en el contrato y por qué. Una o dos frases. -->

## Contexto

- Issue / historia técnica (E0-T2) / ola contractual:
- ADR / decisión afectada (DEC-xxx):
- HU que respalda la superficie (si aplica; no se congela superficie de HU en Borrador):

## Tipo de cambio

- [ ] Nueva superficie de API / evento (aditivo)
- [ ] Cambio incompatible (breaking) — justificar
- [ ] Corrección de contrato (sin superficie nueva)
- [ ] Codegen / tooling
- [ ] Documentación
- [ ] Release de prerelease (nuevo tag `v*-tracer.*`)
- [ ] Otro:

## Cambios

<!-- Qué specs/protos/estados cambiaron y qué se regeneró. -->

-

## Invariantes del freeze (ADR 25)

- [ ] No afecta ninguna invariante.
- [ ] **Una sola corrida de CI** publica fuentes + Go + TS + manifiesto (tag, SHA, checksums) bajo la misma versión.
- [ ] **Contrato primero** — Go y TS se generan de la misma fuente; no hay clientes ni enums escritos a mano como autoridad paralela.
- [ ] **Un cambio incompatible de OpenAPI rompe CI** contra la última release publicada.
- [ ] `buf lint` y `buf breaking` validan los eventos.
- [ ] **Codegen reproducible** — mismo commit + toolchain producen los mismos checksums.
- [ ] Los **contract tests** pasan (consumidor limpio que importa y **ejecuta**, no solo compila).
- [ ] Una corrección no modifica una prerelease ya publicada; se publica otra (expand/contract).

## Sustantivos de dominio

- [ ] Los sustantivos de dominio conservan su forma canónica en español (`viaje`, `catalogos`, `operacion`, `mensajeria`, `identidad`, `reportes`, `Audiencia`, roles, rutas, eventos y esquemas equivalentes). **No se traducen**: romperían la correspondencia entre contratos, código generado y documentación.

## Cómo se probó

- [ ] `make generate` y el árbol regenerado está commiteado (sin deriva)
- [ ] `check-reproducible` falla ante una edición a mano de un generado
- [ ] Breaking check de OpenAPI y `buf breaking` en verde
- [ ] `make contract-tests` (consumidor limpio ejecuta las aserciones)
- [ ] Typecheck del paquete TS

Notas de la verificación:

## Versión / release

<!-- Si este PR publica un tag, deja constancia. tracer.1 y tracer.2 se retiraron; sus nombres no se reutilizan. -->

- Versión objetivo:
- [ ] Manifiesto con tag + SHA + checksums para los artefactos Go y TS

## CHANGELOG

- [ ] Agregué la entrada en `CHANGELOG.md` (fecha+hora, resumen, cambios y archivos; la más reciente al inicio).

## Checklist

- [ ] Comentarios y prosa en español (México); identificadores técnicos en inglés.
- [ ] No commiteé secretos ni tokens (ni en logs ni en el manifiesto).
