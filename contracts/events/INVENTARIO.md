# Inventario contractual de eventos — tracer `v0.1.0-tracer.1`

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
- El tracer usa **sólo la superficie amplia**. La superficie restringida
  (conversación, bandeja, emergencia) es de E3/E7 y **no** entra en `tracer.1`.

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
| `catalogo.actualizado` | 1 | `catalogos` | `operacion` | `entidad` + `entidad_id` | amplia |

## Notas por familia

- **`viaje.*`** — Publicados por `operacion` desde el `outbox` de su módulo, en
  la misma transacción que el cambio (P17). El orden por `viaje_id` garantiza
  que `reportes` proyecta las transiciones de un mismo viaje en secuencia.
- **`sesion.revocada`** — Payload mínimo (`sesion_id`, `revocada_en`,
  `expira_en`). Se entrega por una **cola durable por servicio protegido**; el
  consumidor difunde internamente a todas sus réplicas antes de acusar (E0-T4).
  El corte total respeta los 30 segundos de ADR 26.
- **`catalogo.actualizado`** — Efecto idempotente (invalida caché). Reentregar
  sólo vuelve a invalidar.

## Fuera del tracer (declarado, NO incluido en `tracer.1`)

Las familias de conversación, bandeja y emergencia (E3/E7) pertenecen a la
**superficie restringida** y se incorporan en releases posteriores compatibles.
Los eventos de telemetría/tracking (`sin_senal.*`, `telemetria.*`,
`push.*`) son **V2** y no forman parte de ningún tema, cola ni clave de orden de
V1 (ADR 20).
