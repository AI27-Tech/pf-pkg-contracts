// Command check-estados verifica que el enum `EstadoViaje` declarado en el
// spec OpenAPI de `operacion` coincida, token por token y en orden, con la
// fuente canónica contracts/estados/viaje.estados.yaml (ADR 19).
//
// La fuente canónica es el archivo de estados; el enum de OpenAPI es un espejo.
// Si divergen, CI falla. Esto sostiene el criterio E0-T2 de que el enum
// generado sea idéntico en su fuente entre Go, TS y el contrato HTTP.
//
// Uso:
//
//	go run ./tools/check-estados \
//	    -estados contracts/estados/viaje.estados.yaml \
//	    -openapi contracts/openapi/operacion.yaml
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
	flag.Parse()

	canon, err := tokensCanonicos(*estadosPath)
	if err != nil {
		fatal("leer estados: %v", err)
	}
	espejo, err := tokensOpenAPI(*openapiPath)
	if err != nil {
		fatal("leer openapi: %v", err)
	}

	if !reflect.DeepEqual(canon, espejo) {
		fmt.Fprintln(os.Stderr, "check-estados: DIVERGENCIA entre la fuente canónica y el enum OpenAPI")
		fmt.Fprintf(os.Stderr, "  canónico (%s): %v\n", *estadosPath, canon)
		fmt.Fprintf(os.Stderr, "  openapi  (%s): %v\n", *openapiPath, espejo)
		os.Exit(1)
	}
	fmt.Printf("check-estados: OK — %d estados coinciden entre estados/ y operacion.yaml\n", len(canon))
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

func tokensOpenAPI(path string) ([]string, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	// Navegación mínima: components.schemas.EstadoViaje.enum
	var doc struct {
		Components struct {
			Schemas struct {
				EstadoViaje struct {
					Enum []string `yaml:"enum"`
				} `yaml:"EstadoViaje"`
			} `yaml:"schemas"`
		} `yaml:"components"`
	}
	if err := yaml.Unmarshal(raw, &doc); err != nil {
		return nil, err
	}
	enum := doc.Components.Schemas.EstadoViaje.Enum
	if len(enum) == 0 {
		return nil, fmt.Errorf("no se encontró components.schemas.EstadoViaje.enum en %s", path)
	}
	return enum, nil
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "check-estados: "+format+"\n", args...)
	os.Exit(1)
}
