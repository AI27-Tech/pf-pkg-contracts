// Command check-estados verifica que un enum de estado declarado en el spec
// OpenAPI de `operacion` (`EstadoViaje` o `EstadoSolicitud`, según -schema)
// coincida, token por token y en orden, con su fuente canónica en
// contracts/estados/ (viaje.estados.yaml, ADR 19; solicitud.estados.yaml,
// ADR 38).
//
// La fuente canónica es el archivo de estados; el enum de OpenAPI es un espejo.
// Si divergen, CI falla. Esto sostiene el criterio E0-T2 de que el enum
// generado sea idéntico en su fuente entre Go, TS y el contrato HTTP.
//
// Uso:
//
//	go run ./tools/check-estados \
//	    -estados contracts/estados/viaje.estados.yaml \
//	    -openapi contracts/openapi/operacion.yaml \
//	    -schema EstadoViaje
package main

import (
	"flag"
	"fmt"
	"os"
	"reflect"

	"gopkg.in/yaml.v3"
)

func main() {
	estadosPath := flag.String("estados", "contracts/estados/viaje.estados.yaml", "fuente canónica de estados")
	openapiPath := flag.String("openapi", "contracts/openapi/operacion.yaml", "spec OpenAPI de operacion")
	schema := flag.String("schema", "EstadoViaje", "nombre del esquema enum en components.schemas")
	flag.Parse()

	canon, err := tokensCanonicos(*estadosPath)
	if err != nil {
		fatal("leer estados: %v", err)
	}
	espejo, err := tokensOpenAPI(*openapiPath, *schema)
	if err != nil {
		fatal("leer openapi: %v", err)
	}

	if !reflect.DeepEqual(canon, espejo) {
		fmt.Fprintln(os.Stderr, "check-estados: DIVERGENCIA entre la fuente canónica y el enum OpenAPI")
		fmt.Fprintf(os.Stderr, "  canónico (%s): %v\n", *estadosPath, canon)
		fmt.Fprintf(os.Stderr, "  openapi  (%s): %v\n", *openapiPath, espejo)
		os.Exit(1)
	}
	fmt.Printf("check-estados: OK — %d estados de %s coinciden entre estados/ y operacion.yaml\n", len(canon), *schema)
}

func tokensCanonicos(path string) ([]string, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var s struct {
		Estados []struct {
			Token string `yaml:"token"`
		} `yaml:"estados"`
	}
	if err := yaml.Unmarshal(raw, &s); err != nil {
		return nil, err
	}
	out := make([]string, 0, len(s.Estados))
	for _, e := range s.Estados {
		out = append(out, e.Token)
	}
	return out, nil
}

func tokensOpenAPI(path, schema string) ([]string, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	// Navegación mínima: components.schemas.<schema>.enum
	var doc struct {
		Components struct {
			Schemas map[string]struct {
				Enum []string `yaml:"enum"`
			} `yaml:"schemas"`
		} `yaml:"components"`
	}
	if err := yaml.Unmarshal(raw, &doc); err != nil {
		return nil, err
	}
	enum := doc.Components.Schemas[schema].Enum
	if len(enum) == 0 {
		return nil, fmt.Errorf("no se encontró components.schemas.%s.enum en %s", schema, path)
	}
	return enum, nil
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "check-estados: "+format+"\n", args...)
	os.Exit(1)
}
