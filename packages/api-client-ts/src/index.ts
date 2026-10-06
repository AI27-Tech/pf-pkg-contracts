// Punto de entrada del paquete TypeScript generado por pf-pkg-contracts.
//
// Reexporta las fuentes contractuales generadas: estados (fuente única),
// el registro de tipos de evento, los tipos de OpenAPI por servicio y los tipos
// de evento Protobuf. Este archivo es el único escrito a mano del paquete; el
// resto de `src/` es generado y no se edita a mano.
//
// Hasta tracer.2 estos reexports estaban comentados: el paquete publicaba
// archivos que ningún consumidor podía importar. Ahora están activos, y las
// rutas `./openapi/*` y `./eventos/*` están declaradas en `exports`.
export * as estados from "./estados/viajeEstados.gen.js";
export * as registro from "./registro/registro.gen.js";
export * as roles from "./roles/roles.gen.js";

export * as identidad from "./openapi/identidad.gen.js";
export * as catalogos from "./openapi/catalogos.gen.js";
export * as operacion from "./openapi/operacion.gen.js";
export * as bff from "./openapi/bff.gen.js";
export * as reportes from "./openapi/reportes.gen.js";

// Tipos de evento Protobuf, agrupados por mensaje. El Sobre es la envoltura
// común; el registro de tipos válidos está en `registro` (arriba).
export * as eventosViaje from "./eventos/ai27/eventos/v1/viaje_pb.js";
export * as eventosSesion from "./eventos/ai27/eventos/v1/sesion_pb.js";
export * as eventosCatalogo from "./eventos/ai27/eventos/v1/catalogo_pb.js";
export * as sobre from "./eventos/ai27/eventos/v1/sobre_pb.js";