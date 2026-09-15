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

.PHONY: lint
lint: lint-events lint-openapi ## Corre todos los linters de contrato

.PHONY: lint-events
lint-events: ## buf lint sobre contracts/events
	buf lint

.PHONY: lint-openapi
lint-openapi: ## Valida cada spec de OpenAPI (lint + resolución de $ref)
	@for s in identidad catalogos operacion bff reportes; do \
	  echo "redocly lint $$s"; \
	  $(REDOCLY) lint contracts/openapi/$$s.yaml || exit 1; \
	done

.PHONY: breaking
breaking: ## buf breaking contra la última release publicada (rama principal)
	buf breaking --against '.git#branch=pf-contracts-m'

.PHONY: check-estados
check-estados: ## Verifica que el enum OpenAPI de operacion coincida con estados/
	cd tools/check-estados && go run . \
	  -estados ../../contracts/estados/viaje.estados.yaml \
	  -openapi ../../contracts/openapi/operacion.yaml

.PHONY: check-reproducible
check-reproducible: generate ## Falla si la generación deja diffs (codegen no reproducible)
	@if [ -n "$$(git status --porcelain packages/)" ]; then \
	  echo "ERROR: la generación produjo cambios no commiteados (no reproducible o sin regenerar):"; \
	  git --no-pager diff --stat packages/; \
	  exit 1; \
	fi
	@echo "OK: artefactos generados sin diffs."

.PHONY: verify
verify: lint check-estados ## Verificación estática que no requiere publicar
	cd packages/api-client-go && go build ./... && go vet ./...
	@echo "OK: verify."

.PHONY: manifest
manifest: ## Escribe el manifiesto del tracer (tag, SHA, checksums)
	./scripts/manifiesto.sh
