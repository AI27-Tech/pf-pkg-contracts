# Inventario contractual de eventos — tracer `v0.1.0-tracer.26`

> **La tabla de abajo es prosa; el dato legible por máquina es
> `contracts/events/registro.tipos.yaml`.** Desde `tracer.2` el registro es un
> archivo que las tools leen y sobre el que se generan los clientes Go y TS
> (`tools/gen-registro`), y `make check-registro` falla si esta tabla, el
> registro y los `.proto` dejan de decir lo mismo. Si cambias una fila de aquí,
> cámbiala también allá: el checker es el que mantiene la correspondencia.

Este inventario es parte del contrato (E0-T2). Declara, para cada familia de
evento **aprobada para el tracer**: productor → evento → consumidores durables →
agregado → clave derivable de orden → superficie de sensibilidad.

Reglas que este inventario materializa:

- El orden se preserva **por agregado**. El `MessageGroupId` de SNS/SQS FIFO se
  **deriva de la identidad canónica del agregado**; **no existe una clave
  global** y agregados distintos avanzan sin serializarse entre sí (ADR 29).
- Una familia con nombre o parámetros **no aprobados** no aparece aquí y no
  puede entrar al fanout. Un tipo/versión ausente del registro se rechaza antes
  del fanout y, si llega a un consumidor, se trata como evento venenoso.
- La superficie amplia lleva metadatos no sensibles. Desde `tracer.7` la
  superficie restringida incluye la conversación (E3); desde `tracer.17` también
  la emergencia (E7). La bandeja (revisión de colección) sigue fuera.

## Familias del tracer

| Evento | Versión | Productor | Consumidores durables (V1) | Agregado (clave de orden) | Sensibilidad |
|---|---|---|---|---|---|
| `viaje.creado` | 1 | `operacion` | `mensajeria`, `reportes` | `viaje_id` | amplia |
| `viaje.estado_cambiado` | 1 | `operacion` | `mensajeria`, `reportes` | `viaje_id` | amplia |
| `viaje.asignado` | 1 | `operacion` | `mensajeria`, `reportes` | `viaje_id` | amplia |
| `viaje.reasignado` | 1 | `operacion` | `mensajeria`, `reportes` | `viaje_id` | amplia |
| `viaje.condicion_abierta` | 1 | `operacion` | `mensajeria`, `reportes` | `viaje_id` | amplia |
| `viaje.condicion_cerrada` | 1 | `operacion` | `mensajeria`, `reportes` | `viaje_id` | amplia |
| `viaje.mensajeria_habilitada` | 1 | `operacion` | `mensajeria` | `viaje_id` | amplia |
| `viaje.cliente_actualizado` | 1 | `operacion` | `mensajeria` | `viaje_id` | amplia |
| `viaje.cerrado` | 1 | `operacion` | `mensajeria`, `reportes` | `viaje_id` | amplia |
| `viaje.acceso_revocado` | 1 | `operacion` | `mensajeria`, `realtime` | `viaje_id` | amplia |
| `sesion.revocada` | 1 | `identidad` | `bff`, `operacion`, `catalogos`, `reportes`, `mensajeria`, `realtime` | `sesion_id` | amplia |
| `catalogo.actualizado` | 1 | `catalogos` | `operacion`, `mensajeria` | `entidad` + `entidad_id` | amplia |
| `sujeto.creado` | 1 | `identidad` | `catalogos`, `mensajeria`, `reportes` | `sujeto_id` | amplia |
| `sujeto.desactivado` | 1 | `identidad` | `catalogos`, `mensajeria`, `reportes` | `sujeto_id` | amplia |
| `sujeto.reactivado` | 1 | `identidad` | `catalogos`, `mensajeria`, `reportes` | `sujeto_id` | amplia |
| `rol.asignado` | 1 | `identidad` | `mensajeria`, `reportes` | `sujeto_id` | amplia |
| `rol.revocado` | 1 | `identidad` | `mensajeria`, `reportes` | `sujeto_id` | amplia |
| `conversacion.abierta` | 1 | `mensajeria` | `realtime`, `reportes` | `conversacion_id` | restringida |
| `conversacion.enrutada` | 1 | `mensajeria` | `realtime`, `reportes` | `conversacion_id` | restringida |
| `conversacion.reclamada` | 1 | `mensajeria` | `realtime` | `conversacion_id` | restringida |
| `conversacion.liberada` | 1 | `mensajeria` | `realtime` | `conversacion_id` | restringida |
| `conversacion.transferida` | 1 | `mensajeria` | `realtime`, `reportes` | `conversacion_id` | restringida |
| `conversacion.atendida` | 1 | `mensajeria` | `realtime`, `reportes` | `conversacion_id` | restringida |
| `conversacion.cerrada` | 1 | `mensajeria` | `realtime`, `reportes` | `conversacion_id` | restringida |
| `mensaje.creado` | 1 | `mensajeria` | `realtime`, `reportes` | `conversacion_id` | restringida |
| `recibo.entregado` | 1 | `mensajeria` | `realtime` | `conversacion_id` | restringida |
| `recibo.leido` | 1 | `mensajeria` | `realtime` | `conversacion_id` | restringida |
| `membresia.cambiada` | 1 | `mensajeria` | `realtime` | `bandeja_id` | restringida |
| `emergencia.activada` | 1 | `mensajeria` | `realtime`, `reportes` | `caso_emergencia_id` | restringida |
| `emergencia.nota_agregada` | 1 | `mensajeria` | `realtime`, `reportes`, `operacion` | `caso_emergencia_id` | restringida |
| `emergencia.reclamada` | 1 | `mensajeria` | `realtime` | `caso_emergencia_id` | restringida |
| `emergencia.transferida` | 1 | `mensajeria` | `realtime`, `reportes` | `caso_emergencia_id` | restringida |
| `emergencia.resuelta` | 1 | `mensajeria` | `realtime`, `reportes` | `caso_emergencia_id` | restringida |
| `emergencia.cerrada` | 1 | `mensajeria` | `realtime`, `reportes` | `caso_emergencia_id` | restringida |

## Notas por familia

- **`viaje.*`** — Publicados por `operacion` desde el `outbox` de su módulo, en
  la misma transacción que el cambio (P17). El orden por `viaje_id` garantiza
  que `reportes` proyecta las transiciones de un mismo viaje en secuencia.
- **`sesion.revocada`** — Payload mínimo (`sesion_id`, `revocada_en`,
  `expira_en`). Se entrega por una **cola durable por servicio protegido**; el
  consumidor difunde internamente a todas sus réplicas antes de acusar (E0-T4).
  El corte total respeta los 30 segundos de ADR 26.
- **`catalogo.actualizado`** — Efecto idempotente (invalida caché). Reentregar
  sólo vuelve a invalidar. Desde `tracer.7` también lo consume `mensajeria`
  (caché de cliente para la lectura por lote).
- **`sujeto.creado`, `sujeto.desactivado`, `sujeto.reactivado`, `rol.asignado`,
  `rol.revocado`** (`sujeto.*`/`rol.*` desde `tracer.7`; `creado`/`reactivado`
  agregados después) — Publicados por `identidad` (gobierno E4-T6). `creado` y
  `reactivado` son hechos propios de ciclo de vida del sujeto; el alta publica
  `sujeto.creado` + `rol.asignado` en la misma transacción. Son la fuente de la
  proyección de pool de `mensajeria`. El alcance por `cliente`/`unidad` NO viaja
  aquí: su evento sigue pendiente (identidad.md (g), DEC-045).
- **Conversación (`conversacion.*`, `mensaje.*`, `recibo.*`,
  `membresia.cambiada`)** (`tracer.7`) — Superficie **restringida**. Viajan por
  el tema restringido envueltos en `SobreVivo` (`sobre_vivo.proto`), que lleva
  `cursor_dominio`, `audience_version` y `target_sujeto_ids` (ADR 28 §4).
  `actor_real` no viaja: queda en la auditoría local de `mensajeria`.
- **Emergencia (`emergencia.*`)** (`tracer.17`) — Superficie **restringida**,
  mismo transporte que la conversación (`SobreVivo` por el tema restringido).
  Agregado = `caso_emergencia_id`. `emergencia.nota_agregada` suma `operacion`
  como consumidor durable: proyecta la nota al histórico interno del viaje
  (DEC-100 punto 1). `actor_real` no viaja; el cliente solo ve la vista mínima
  (ADR 21 §6).

## Fuera del tracer (declarado, NO incluido)

La familia de **bandeja** (revisión de colección) pertenece a la superficie
restringida y sigue declarada fuera. La familia de **emergencia** (E7) entró en
`tracer.17` (ver tabla).
Los eventos de telemetría/tracking (`sin_senal.*`, `telemetria.*`,
`push.*`) son **V2** y no forman parte de ningún tema, cola ni clave de orden de
V1 (ADR 20).
