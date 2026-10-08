// Command breaking-gate decide si las rupturas que una herramienta de
// compatibilidad reportó están TODAS declaradas en la allowlist de la versión
// actual. Es el mecanismo de D4 (`tracer.4`): el gate sigue fallando ante
// cualquier ruptura, salvo las listadas en `rompimientos/${VERSION}.yaml`, y
// sólo mientras `VERSION` sea exactamente la del nombre de ese archivo.
//
// Lee la salida de la herramienta por STDIN y falla (exit 1) si alguna ruptura
// no está autorizada. Si no hay allowlist para la versión actual, ninguna
// ruptura está autorizada: cualquier ruptura falla.
//
// Dos modos:
//
//	-tipo openapi  -servicio catalogos   # consume el texto de oasdiff
//	-tipo eventos                        # consume el texto de buf breaking
//
// El matcher es por SUBCADENA sobre el texto que emite la herramienta: cada
// entrada de la allowlist lleva `match`, y una ruptura queda autorizada cuando
// su línea identificadora contiene ese `match`. Para OpenAPI el matcher usa la
// línea `in API <método ruta>` que oasdiff imprime; para eventos, el mensaje
// que buf imprime por ruptura.
package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

type entrada struct {
	Servicio string `yaml:"servicio"`
	Match    string `yaml:"match"`
	Fuente   string `yaml:"fuente"`
}

type allowlist struct {
	Version string    `yaml:"version"`
	OpenAPI []entrada `yaml:"openapi"`
	Eventos []entrada `yaml:"eventos"`
}

func main() {
	tipo := flag.String("tipo", "", "openapi | eventos")
	servicio := flag.String("servicio", "", "servicio OpenAPI (sólo con -tipo openapi)")
	version := flag.String("version", "", "versión actual (contenido de VERSION)")
	dir := flag.String("rompimientos", "rompimientos", "directorio de allowlists por versión")
	flag.Parse()

	if *tipo != "openapi" && *tipo != "eventos" {
		fatal("-tipo debe ser openapi o eventos")
	}
	if *version == "" {
		fatal("-version es obligatorio")
	}

	// La allowlist se busca por el nombre de la versión actual. Si no existe,
	// no hay ruptura autorizada: cualquiera falla.
	ruptturas, err := leerRupturas(*tipo, os.Stdin)
	if err != nil {
		fatal("leer la salida de la herramienta: %v", err)
	}
	if len(ruptturas) == 0 {
		// Nada rompió: el gate ya decidió verde antes de llamarnos. No-op.
		return
	}

	path := fmt.Sprintf("%s/%s.yaml", strings.TrimRight(*dir, "/"), *version)
	al, err := leerAllowlist(path)
	if err != nil {
		// Sin allowlist para esta versión, ninguna ruptura está declarada.
		fmt.Fprintf(os.Stderr,
			"breaking-gate: hay %d ruptura(s) y no existe allowlist %s: ninguna está declarada.\n",
			len(ruptturas), path)
		imprimirNoAutorizadas(ruptturas, nil, *tipo, *servicio)
		os.Exit(1)
	}
	// El nombre del archivo y su campo `version` deben coincidir con VERSION:
	// una allowlist sólo autoriza su propia versión (D4).
	if al.Version != *version {
		fatal("la allowlist %s declara version %q, pero VERSION es %q: no aplica",
			path, al.Version, *version)
	}

	entradas := al.OpenAPI
	if *tipo == "eventos" {
		entradas = al.Eventos
	}

	var noAutorizadas []string
	for _, r := range ruptturas {
		if !autorizada(r, entradas, *tipo, *servicio) {
			noAutorizadas = append(noAutorizadas, r)
		}
	}
	if len(noAutorizadas) > 0 {
		fmt.Fprintf(os.Stderr,
			"breaking-gate: %d ruptura(s) NO declarada(s) en %s:\n", len(noAutorizadas), path)
		for _, r := range noAutorizadas {
			fmt.Fprintf(os.Stderr, "  - %s\n", r)
		}
		fmt.Fprintln(os.Stderr,
			"  Si son intencionales, decláralas con su fuente (ADR/DEC); si no, revierte el cambio.")
		os.Exit(1)
	}

	fmt.Printf("breaking-gate: OK — las %d ruptura(s) están declaradas en %s.\n",
		len(ruptturas), path)
}

// autorizada indica si una ruptura casa con alguna entrada de la allowlist.
// Para OpenAPI, además, la entrada debe ser del mismo servicio.
func autorizada(ruptura string, entradas []entrada, tipo, servicio string) bool {
	for _, e := range entradas {
		if tipo == "openapi" && e.Servicio != "" && e.Servicio != servicio {
			continue
		}
		if e.Match != "" && strings.Contains(ruptura, e.Match) {
			return true
		}
	}
	return false
}

func imprimirNoAutorizadas(ruptturas []string, _ []entrada, _, _ string) {
	for _, r := range ruptturas {
		fmt.Fprintf(os.Stderr, "  - %s\n", r)
	}
}

// leerRupturas extrae, de la salida de la herramienta, la línea identificadora
// de cada ruptura que el gate debe autorizar.
//
//   - openapi (oasdiff --format text --fail-on ERR): toma la línea `in API
//     <método ruta>` de cada bloque cuyo severity sea `error`. Las `warning` no
//     fallan el gate, así que no se incluyen.
//   - eventos (buf breaking): cada línea `archivo:fila:col:mensaje` es una
//     ruptura; se toma el mensaje.
func leerRupturas(tipo string, r *os.File) ([]string, error) {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)

	var out []string
	if tipo == "openapi" {
		enError := false
		for sc.Scan() {
			line := sc.Text()
			trimmed := strings.TrimSpace(line)
			switch {
			case strings.HasPrefix(trimmed, "error\t"), strings.HasPrefix(trimmed, "error ["):
				enError = true
			case strings.HasPrefix(trimmed, "warning"), strings.HasPrefix(trimmed, "info"):
				enError = false
			case enError && strings.HasPrefix(trimmed, "in API "):
				out = append(out, strings.TrimPrefix(trimmed, "in API "))
				enError = false
			}
		}
		return out, sc.Err()
	}

	// eventos: cada línea no vacía con al menos tres ':' es una ruptura de buf.
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, ":", 4)
		if len(parts) < 4 {
			continue
		}
		out = append(out, strings.TrimSpace(parts[3]))
	}
	return out, sc.Err()
}

func leerAllowlist(path string) (*allowlist, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var al allowlist
	if err := yaml.Unmarshal(raw, &al); err != nil {
		return nil, fmt.Errorf("allowlist YAML inválido: %w", err)
	}
	return &al, nil
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "breaking-gate: "+format+"\n", args...)
	os.Exit(2)
}
