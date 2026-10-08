# =============================================================================
# pf-pkg-contracts — Makefile
# -----------------------------------------------------------------------------
# Objetivos que usan tanto el desarrollo local como CI. La generación es el
# único camino de codegen (scripts/generar.sh) y es reproducible (ADR 25).
# =============================================================================
.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

# Herramientas fijadas por versión (mismas que usa CI).
BUF_VERSION        ?= 1.45.0
REDOCLY            ?= npx --yes @redocly/cli@1.25.11
OPENAPI_TS         ?= npx --yes openapi-typescript@7.4.4

.PHONY: help
help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	 awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-22s\033[0m %s\n",$$1,$$2}'

.PHONY: generate
generate: ## Genera todos los artefactos Go y TS desde las fuentes
	./scripts/generar.sh

.PHONY: generate-estados
generate-estados: ## Genera solo los tipos de estados (Go + TS)
	cd tools/gen-estados && go run . \
	  -src ../../contracts/estados/viaje.estados.yaml \
	  -go ../../packages/api-client-go/estados/viaje_estados.gen.go \
	  -ts ../../packages/api-client-ts/src/estados/viajeEstados.gen.ts

.PHONY: generate-registro
generate-registro: ## Genera solo el registro de tipos de evento (Go + TS)
	cd tools/gen-registro && go run . \
	  -src ../../contracts/events/registro.tipos.yaml \
	  -go ../../packages/api-client-go/registro/registro.gen.go \
	  -ts ../../packages/api-client-ts/src/registro/registro.gen.ts

.PHONY: generate-roles
generate-roles: ## Genera solo el enum de roles (Go + TS)
	cd tools/gen-roles && go run . \
	  -src ../../contracts/openapi/_comunes.yaml \
	  -go ../../packages/api-client-go/roles/roles.gen.go \
	  -ts ../../packages/api-client-ts/src/roles/roles.gen.ts

.PHONY: lint
lint: lint-events lint-openapi ## Corre todos los linters de contrato

.PHONY: lint-events
lint-events: ## buf lint sobre contracts/events
	buf lint

.PHONY: lint-openapi
lint-openapi: ## Valida cada spec de OpenAPI (bundle + lint con $ref resueltos)
	@tmp="$$(mktemp -d)"; \
	for s in identidad catalogos operacion bff reportes; do \
	  echo "bundle + redocly lint $$s"; \
	  $(REDOCLY) bundle contracts/openapi/$$s.yaml -o "$$tmp/$$s.bundle.yaml" >/dev/null || { rm -rf "$$tmp"; exit 1; }; \
	  $(REDOCLY) lint "$$tmp/$$s.bundle.yaml" || { rm -rf "$$tmp"; exit 1; }; \
	done; \
	rm -rf "$$tmp"

.PHONY: breaking
breaking: ## buf breaking de eventos con allowlist por versión (rompimientos/)
	./scripts/breaking-eventos.sh

.PHONY: test-breaking-gate
test-breaking-gate: ## Prueba el mecanismo de allowlist: una ruptura no listada falla (D4)
	./scripts/test-breaking-gate.sh

.PHONY: breaking-openapi
breaking-openapi: ## Rompe CI ante un cambio incompatible de OpenAPI vs la última release
	./scripts/breaking-openapi.sh

# oasdiff se ancla en tools/oasdiff (ver tools/oasdiff/tools.go) para que el
# veredicto sea el mismo en local y en CI. Fijado en v1.11.7; no actualizar sin
# revisar el diff que introduce.

.PHONY: check-estados
check-estados: ## Verifica que el enum OpenAPI de operacion coincida con estados/
	cd tools/check-estados && go run . \
	  -estados ../../contracts/estados/viaje.estados.yaml \
	  -openapi ../../contracts/openapi/operacion.yaml

.PHONY: check-registro
check-registro: ## Verifica que registro, .proto e INVENTARIO.md coincidan
	cd tools/check-registro && go run . \
	  -registro ../../contracts/events/registro.tipos.yaml \
	  -proto ../../contracts/events \
	  -inventario ../../contracts/events/INVENTARIO.md

.PHONY: check-tags
check-tags: ## Falla si el árbol etiquetado no trae cada paquete publicado
	./scripts/check-tags.sh

.PHONY: check-reproducible
check-reproducible: check-no-ignorados check-arbol-limpio generate ## Falla si alguien editó a mano un artefacto generado
	./scripts/check-reproducible.sh

.PHONY: check-arbol-limpio
check-arbol-limpio: ## Falla si packages/ ya difiere de HEAD ANTES de regenerar
	# Detecta la edición a mano de un cliente generado cuando aún no se ha
	# regenerado: `make generate` sobrescribe el archivo, así que el diff de
	# después no la vería. Si el árbol ya difiere de lo commiteado, alguien tocó
	# un *.gen.* a mano (o no regeneró tras cambiar la fuente).
	@if [ -n "$$(git status --porcelain packages/)" ]; then \
		echo "ERROR: packages/ ya difiere de HEAD antes de regenerar."; \
		git --no-pager diff --stat packages/; \
		echo "       Los *.gen.* no se editan a mano: cambia la fuente en contracts/"; \
		echo "       y vuelve a generar, o revierte el cambio."; \
		exit 1; \
	fi
	@echo "OK: packages/ coincide con HEAD antes de regenerar."

.PHONY: check-no-ignorados
check-no-ignorados: ## Falla si algún artefacto generado está en .gitignore
	# Sin este chequeo, `git status --porcelain packages/` no ve lo ignorado y
	# check-reproducible da verde con deriva fuente<->artefacto. Así fue como
	# v0.1.0-tracer.1 publicó el módulo Go sin los clientes (C1 del handoff).
	#
	# Se miran sólo los directorios de ARTEFACTOS GENERADOS; `node_modules/` sí
	# debe seguir ignorado (es una dependencia instalada, no un artefacto
	# contractual).
	@ignorado="$$(git ls-files --others --ignored --exclude-standard -- \
	  packages/api-client-go packages/api-client-ts/src | \
	  grep -v '^packages/api-client-ts/src/.*/node_modules/' || true)"; \
	if [ -n "$$ignorado" ]; then \
		echo "ERROR: hay artefactos generados que .gitignore excluye."; \
		echo "       No se publicarían en el tag, que es exactamente el defecto de tracer.1:"; \
		echo "$$ignorado"; \
		exit 1; \
	fi
	@echo "OK: ningún artefacto generado está ignorado."

.PHONY: verify
verify: lint check-estados check-registro check-tags ## Verificación estática que no requiere publicar
	cd packages/api-client-go && go build ./... && go vet ./...
	@echo "OK: verify."

.PHONY: contract-tests
contract-tests: ## Contract tests del repo (consumidor limpio + consistencia del registro)
	./scripts/contract-tests.sh

.PHONY: check-ts-exports
check-ts-exports: ## Empaqueta el paquete npm y resuelve cada subpath de 'exports' desde el tarball
	./scripts/check-ts-exports.sh

.PHONY: manifest
manifest: ## Escribe el manifiesto del tracer (tag, SHA, checksums)
	./scripts/manifiesto.sh

.PHONY: verificar-manifiesto
verificar-manifiesto: ## Verifica que el manifiesto congela el árbol actual (coherencia y completitud)
	./scripts/verificar-manifiesto.sh
