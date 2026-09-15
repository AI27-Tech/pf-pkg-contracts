// Punto de entrada del paquete TypeScript generado por pf-pkg-contracts.
// Reexporta los estados (fuente única) y, cuando el codegen corre, los tipos
// de OpenAPI por servicio y los tipos de evento. Este archivo es el único
// escrito a mano del paquete; el resto de `src/` es generado.

export * as estados from "./estados/viajeEstados.gen.js";

// Los siguientes reexports quedan disponibles tras `make generate` (CI):
//   export * as identidad from "./openapi/identidad.gen.js";
//   export * as catalogos from "./openapi/catalogos.gen.js";
//   export * as operacion from "./openapi/operacion.gen.js";
//   export * as bff from "./openapi/bff.gen.js";
//   export * as reportes from "./openapi/reportes.gen.js";
//   export * as eventos from "./eventos/ai27/eventos/v1/index.js";
