// Package apiclientgo es el módulo Go publicado por pf-pkg-contracts.
//
// Contiene tipos y clientes generados desde las fuentes contractuales:
//   - estados/  — máquina de estados del viaje (generado por tools/gen-estados
//     desde contracts/estados/viaje.estados.yaml).
//   - <servicio>/ — tipos y cliente HTTP por servicio (generado por
//     oapi-codegen desde contracts/openapi, tras `make generate`).
//   - eventos/  — tipos de evento Protobuf (generado por buf, tras `make generate`).
//
// Los consumidores lo fijan por versión exacta (tag v0.1.0-tracer.1). Nadie lo
// consume por ruta relativa (CONTRACTS_DIR), branch mutable ni `latest`
// (ADR 25). Los archivos *.gen.go son generados: no se editan a mano.
package apiclientgo
