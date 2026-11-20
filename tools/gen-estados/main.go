// Command gen-estados genera los tipos de una máquina de estados (`viaje` o
// `solicitud`, según `aggregate` de la fuente) para Go y TypeScript desde la
// fuente única contracts/estados/<agregado>.estados.yaml.
//
// Criterio de aceptación (E0-T2): el enum generado en Go y en TypeScript es
// idéntico en su fuente (mismo archivo de origen). Este generador es esa fuente
// de generación: nadie edita a mano los archivos de salida.
//
// Uso:
//
//	go run ./tools/gen-estados \
//	    -src contracts/estados/viaje.estados.yaml \
//	    -go  packages/api-client-go/estados/viaje_estados.gen.go \
//	    -ts  packages/api-client-ts/src/estados/viajeEstados.gen.ts
//
// La generación es reproducible: el mismo commit y toolchain producen los
// mismos bytes de salida (ver Makefile y CI).
package main

import (
	"bytes"
	"flag"
	"fmt"
	"go/format"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

type estado struct {
	Token        string   `yaml:"token"`
	NombreNeg    string   `yaml:"nombre_negocio"`
	Availability string   `yaml:"availability"`
	Terminal     bool     `yaml:"terminal"`
	ReachableV1  *bool    `yaml:"reachable_v1"`
	Descripcion  string   `yaml:"descripcion"`
	AliasHist    []string `yaml:"alias_historico"`
}

type transicion struct {
	De         string `yaml:"de"`
	A          string `yaml:"a"`
	Disparador string `yaml:"disparador"`
	Guarda     string `yaml:"guarda"`
	Nota       string `yaml:"nota"`
}

type condTipo struct {
	Token        string `yaml:"token"`
	NombreNeg    string `yaml:"nombre_negocio"`
	Availability string `yaml:"availability"`
	Descripcion  string `yaml:"descripcion"`
}

type source struct {
	Version      int    `yaml:"version"`
	Aggregate    string `yaml:"aggregate"`
	Estados      []estado
	Transiciones []transicion
	Condicion    struct {
		Tipos []condTipo `yaml:"tipos"`
	} `yaml:"condicion_viaje"`
}

func main() {
	src := flag.String("src", "contracts/estados/viaje.estados.yaml", "ruta de la fuente YAML")
	goOut := flag.String("go", "", "ruta de salida Go")
	tsOut := flag.String("ts", "", "ruta de salida TypeScript")
	flag.Parse()

	raw, err := os.ReadFile(*src)
	if err != nil {
		fatal("no se pudo leer la fuente: %v", err)
	}
	var s source
	if err := yaml.Unmarshal(raw, &s); err != nil {
		fatal("YAML inválido: %v", err)
	}
	if err := validate(&s); err != nil {
		fatal("fuente inconsistente: %v", err)
	}
	n, err := nombresDe(s.Aggregate)
	if err != nil {
		fatal("%v", err)
	}

	if *goOut != "" {
		formatted, err := format.Source(genGo(&s, n))
		if err != nil {
			fatal("gofmt del Go generado: %v", err)
		}
		if err := writeFile(*goOut, formatted); err != nil {
			fatal("escribir Go: %v", err)
		}
		fmt.Fprintf(os.Stderr, "gen-estados: escrito %s\n", *goOut)
	}
	if *tsOut != "" {
		if err := writeFile(*tsOut, genTS(&s, n)); err != nil {
			fatal("escribir TS: %v", err)
		}
		fmt.Fprintf(os.Stderr, "gen-estados: escrito %s\n", *tsOut)
	}
}

// validate comprueba las invariantes que el grafo generado debe probar (E1-T1):
// tokens únicos, transiciones que referencian estados existentes, y que ningún
// estado terminal tenga transiciones de salida.
func validate(s *source) error {
	known := map[string]estado{}
	for _, e := range s.Estados {
		if e.Token == "" {
			return fmt.Errorf("estado sin token")
		}
		if _, dup := known[e.Token]; dup {
			return fmt.Errorf("token duplicado: %s", e.Token)
		}
		known[e.Token] = e
	}
	for _, t := range s.Transiciones {
		if _, ok := known[t.De]; !ok {
			return fmt.Errorf("transición desde estado desconocido: %s", t.De)
		}
		if _, ok := known[t.A]; !ok {
			return fmt.Errorf("transición hacia estado desconocido: %s", t.A)
		}
		if known[t.De].Terminal {
			return fmt.Errorf("estado terminal %s no puede tener transición de salida", t.De)
		}
	}
	return nil
}

// nombres fija los identificadores generados por agregado. El viaje conserva
// los nombres históricos (el consumo existente no cambia); los demás agregados
// llevan su nombre como sufijo o prefijo para no chocar en el paquete `estados`.
type nombres struct {
	Fuente       string // ruta de la fuente y ADR, para el encabezado
	Desc         string // "del viaje", "de la solicitud"
	Tipo         string // tipo Go y TS del estado
	PrefijoGo    string // prefijo de las constantes Go
	ListaGo      string
	StructTrans  string
	VarTrans     string
	FnPuedeGo    string
	ListaTS      string
	TerminalesTS string
	FnTerminalTS string
	TransTS      string
	FnPuedeTS    string
}

func nombresDe(agg string) (nombres, error) {
	switch agg {
	case "viaje":
		return nombres{
			Fuente: "contracts/estados/viaje.estados.yaml (ADR 19)", Desc: "del viaje",
			Tipo: "EstadoViaje", PrefijoGo: "Estado", ListaGo: "EstadosViaje",
			StructTrans: "transicion", VarTrans: "transicionesViaje", FnPuedeGo: "PuedeTransicionar",
			ListaTS: "ESTADOS_VIAJE", TerminalesTS: "ESTADOS_TERMINALES", FnTerminalTS: "esTerminal",
			TransTS: "TRANSICIONES_VIAJE", FnPuedeTS: "puedeTransicionar",
		}, nil
	case "solicitud":
		return nombres{
			Fuente: "contracts/estados/solicitud.estados.yaml (ADR 38)", Desc: "de la solicitud",
			Tipo: "EstadoSolicitud", PrefijoGo: "EstadoSolicitud", ListaGo: "EstadosSolicitud",
			StructTrans: "transicionSolicitud", VarTrans: "transicionesSolicitud", FnPuedeGo: "PuedeTransicionarSolicitud",
			ListaTS: "ESTADOS_SOLICITUD", TerminalesTS: "ESTADOS_TERMINALES_SOLICITUD", FnTerminalTS: "esTerminalSolicitud",
			TransTS: "TRANSICIONES_SOLICITUD", FnPuedeTS: "puedeTransicionarSolicitud",
		}, nil
	}
	return nombres{}, fmt.Errorf("agregado desconocido: %q (se esperaba viaje o solicitud)", agg)
}

func genGo(s *source, n nombres) []byte {
	var b bytes.Buffer
	b.WriteString("// Code generated by tools/gen-estados. DO NOT EDIT.\n")
	fmt.Fprintf(&b, "// Fuente: %s.\n\n", n.Fuente)
	b.WriteString("package estados\n\n")

	fmt.Fprintf(&b, "// %s es un estado de progreso %s. Enum como dato (P14).\n", n.Tipo, n.Desc)
	fmt.Fprintf(&b, "type %s string\n\n", n.Tipo)
	b.WriteString("const (\n")
	for _, e := range s.Estados {
		fmt.Fprintf(&b, "\t%s%s %s = %q\n", n.PrefijoGo, camel(e.Token), n.Tipo, e.Token)
	}
	b.WriteString(")\n\n")

	// Lista completa ordenada por declaración.
	fmt.Fprintf(&b, "// %s son todos los estados declarados, incluidos los de V2 inalcanzables.\n", n.ListaGo)
	fmt.Fprintf(&b, "var %s = []%s{\n", n.ListaGo, n.Tipo)
	for _, e := range s.Estados {
		fmt.Fprintf(&b, "\t%s%s,\n", n.PrefijoGo, camel(e.Token))
	}
	b.WriteString("}\n\n")

	// Terminales.
	b.WriteString("// EsTerminal indica si un estado no admite transiciones de salida.\n")
	fmt.Fprintf(&b, "func (e %s) EsTerminal() bool {\n\tswitch e {\n", n.Tipo)
	var terms []string
	for _, e := range s.Estados {
		if e.Terminal {
			terms = append(terms, n.PrefijoGo+camel(e.Token))
		}
	}
	if len(terms) > 0 {
		fmt.Fprintf(&b, "\tcase %s:\n\t\treturn true\n", strings.Join(terms, ", "))
	}
	b.WriteString("\t}\n\treturn false\n}\n\n")

	// Transiciones.
	b.WriteString("// transicion es una arista permitida de la máquina de estados.\n")
	fmt.Fprintf(&b, "type %s struct{ De, A %s }\n\n", n.StructTrans, n.Tipo)
	fmt.Fprintf(&b, "// %s son las aristas permitidas (de -> a). Generadas desde la fuente.\n", n.VarTrans)
	fmt.Fprintf(&b, "var %s = []%s{\n", n.VarTrans, n.StructTrans)
	for _, t := range s.Transiciones {
		fmt.Fprintf(&b, "\t{De: %s%s, A: %s%s},\n", n.PrefijoGo, camel(t.De), n.PrefijoGo, camel(t.A))
	}
	b.WriteString("}\n\n")
	fmt.Fprintf(&b, "// %s indica si `de -> a` es una transición permitida.\n", n.FnPuedeGo)
	fmt.Fprintf(&b, "func %s(de, a %s) bool {\n", n.FnPuedeGo, n.Tipo)
	fmt.Fprintf(&b, "\tfor _, t := range %s {\n\t\tif t.De == de && t.A == a {\n\t\t\treturn true\n\t\t}\n\t}\n\treturn false\n}\n", n.VarTrans)

	// Condiciones ortogonales (solo el viaje las tiene).
	if len(s.Condicion.Tipos) > 0 {
		b.WriteString("\n// CondicionViaje es una condición ORTOGONAL al progreso (P15). Nunca es un estado.\n")
		b.WriteString("type CondicionViaje string\n\n")
		b.WriteString("const (\n")
		for _, c := range s.Condicion.Tipos {
			fmt.Fprintf(&b, "\tCondicion%s CondicionViaje = %q\n", camel(c.Token), c.Token)
		}
		b.WriteString(")\n")
	}

	return b.Bytes()
}

func genTS(s *source, n nombres) []byte {
	var b bytes.Buffer
	b.WriteString("// Code generated by tools/gen-estados. DO NOT EDIT.\n")
	fmt.Fprintf(&b, "// Fuente: %s.\n\n", n.Fuente)

	fmt.Fprintf(&b, "/** Estado de progreso %s. Enum como dato (P14). */\n", n.Desc)
	fmt.Fprintf(&b, "export const %s = {\n", n.Tipo)
	for _, e := range s.Estados {
		fmt.Fprintf(&b, "  %s: %q,\n", camel(e.Token), e.Token)
	}
	b.WriteString("} as const;\n\n")
	fmt.Fprintf(&b, "export type %s = (typeof %s)[keyof typeof %s];\n\n", n.Tipo, n.Tipo, n.Tipo)

	b.WriteString("/** Todos los estados declarados, incluidos los de V2 inalcanzables. */\n")
	fmt.Fprintf(&b, "export const %s: readonly %s[] = [\n", n.ListaTS, n.Tipo)
	for _, e := range s.Estados {
		fmt.Fprintf(&b, "  %s.%s,\n", n.Tipo, camel(e.Token))
	}
	b.WriteString("];\n\n")

	b.WriteString("/** Estados terminales (sin transiciones de salida). */\n")
	fmt.Fprintf(&b, "export const %s: readonly %s[] = [\n", n.TerminalesTS, n.Tipo)
	for _, e := range s.Estados {
		if e.Terminal {
			fmt.Fprintf(&b, "  %s.%s,\n", n.Tipo, camel(e.Token))
		}
	}
	b.WriteString("];\n\n")
	fmt.Fprintf(&b, "export function %s(e: %s): boolean {\n  return %s.includes(e);\n}\n\n", n.FnTerminalTS, n.Tipo, n.TerminalesTS)

	b.WriteString("/** Aristas permitidas de la máquina de estados (de -> a). */\n")
	fmt.Fprintf(&b, "export const %s: ReadonlyArray<readonly [%s, %s]> = [\n", n.TransTS, n.Tipo, n.Tipo)
	for _, t := range s.Transiciones {
		fmt.Fprintf(&b, "  [%s.%s, %s.%s],\n", n.Tipo, camel(t.De), n.Tipo, camel(t.A))
	}
	b.WriteString("];\n\n")
	fmt.Fprintf(&b, "export function %s(de: %s, a: %s): boolean {\n", n.FnPuedeTS, n.Tipo, n.Tipo)
	fmt.Fprintf(&b, "  return %s.some(([d, x]) => d === de && x === a);\n}\n", n.TransTS)

	if len(s.Condicion.Tipos) > 0 {
		b.WriteString("\n/** Condición ORTOGONAL al progreso (P15). Nunca es un estado. */\n")
		b.WriteString("export const CondicionViaje = {\n")
		for _, c := range s.Condicion.Tipos {
			fmt.Fprintf(&b, "  %s: %q,\n", camel(c.Token), c.Token)
		}
		b.WriteString("} as const;\n\n")
		b.WriteString("export type CondicionViaje = (typeof CondicionViaje)[keyof typeof CondicionViaje];\n")
	}

	return b.Bytes()
}

// camel convierte SOLICITADO -> Solicitado, RECHAZADO_POR_AI27 -> RechazadoPorAi27.
func camel(token string) string {
	parts := strings.Split(strings.ToLower(token), "_")
	for i, p := range parts {
		if p == "" {
			continue
		}
		parts[i] = strings.ToUpper(p[:1]) + p[1:]
	}
	return strings.Join(parts, "")
}

func writeFile(path string, data []byte) error {
	if err := os.MkdirAll(dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o644)
}

func dir(path string) string {
	if i := strings.LastIndex(path, "/"); i >= 0 {
		return path[:i]
	}
	return "."
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "gen-estados: "+format+"\n", args...)
	os.Exit(1)
}
