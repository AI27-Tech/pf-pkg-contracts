// Command check-registro verifica que las TRES Representations del registro de
// tipos de evento digan exactamente lo mismo:
//
//  1. contracts/events/registro.tipos.yaml — el dato (C5).
//  2. contracts/events/ai27/eventos/v1/*.proto — los mensajes que existen.
//  3. contracts/events/INVENTARIO.md — la tabla en prosa que ya existía.
//
// Si divergen, el contrato tiene dos verdades y el fanout puedeValidar un tipo
// que no tiene mensaje, o un mensaje que el registro no autoriza. CI falla.
//
// Relación 1 <-> 2 (nombres): el registro usa el nombre de evento canónico
// (`viaje.estado_cambiado`, snake_case de dominio, ADR 22) y los .proto
// declaran mensajes en PascalCase (`ViajeEstadoCambiado`). La correspondencia es
// la conversión snake_case <-> PascalCase sobre el nombre SIN el prefijo de
// familia. Este checker la aplica; nadie mantiene la lista a mano.
//
// `Sobre` es la envoltura común, no un tipo de evento: no debe aparecer en el
// registro.
//
// Uso:
//
//	go run ./tools/check-registro \
//	    -registro contracts/events/registro.tipos.yaml \
//	    -proto    contracts/events \
//	    -inventario contracts/events/INVENTARIO.md
package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

type tipoEvento struct {
	Tipo                 string   `yaml:"tipo"`
	Version              uint32   `yaml:"version"`
	Productor            string   `yaml:"productor"`
	ConsumidoresDurables []string `yaml:"consumidores_durables"`
	Agregado             string   `yaml:"agregado"`
	Sensibilidad         string   `yaml:"sensibilidad"`
}

type source struct {
	Version int         `yaml:"version"`
	Tipos   []tipoEvento `yaml:"tipos"`
}

// sobreEnvoltura es el mensaje que envuelve a todos los demás: no es un tipo de
// evento y por tanto no puede estar en el registro.
const sobreEnvoltura = "Sobre"

// mensajeProto extrae un mensaje de nivel superior de un archivo .proto.
var reMensaje = regexp.MustCompile(`(?m)^message\s+([A-Za-z0-9_]+)\s*\{`)

// filaInventario extrae una fila de la tabla del inventario. Formato:
//
//	| `viaje.creado` | 1 | `operacion` | `mensajeria`, `reportes` | `viaje_id` | amplia |
var reFilaInventario = regexp.MustCompile(
	`^\|\s*` + "`([^`]+)`" + `\s*\|\s*(\d+)\s*\|` +
		`\s*` + "`([^`]+)`" + `\s*\|([^|]*)\|` +
		`\s*([^|]*)\|\s*([A-Za-z_]+)\s*\|`)

func main() {
	regPath := flag.String("registro", "contracts/events/registro.tipos.yaml", "fuente del registro")
	protoDir := flag.String("proto", "contracts/events", "directorio con los .proto")
	invPath := flag.String("inventario", "contracts/events/INVENTARIO.md", "tabla en prosa")
	flag.Parse()

	raw, err := os.ReadFile(*regPath)
	if err != nil {
		fatal("no se pudo leer el registro: %v", err)
	}
	var s source
	if err := yaml.Unmarshal(raw, &s); err != nil {
		fatal("YAML inválido: %v", err)
	}
	if len(s.Tipos) == 0 {
		fatal("el registro no declara ningún tipo")
	}

	msgs, err := mensajesDeProto(*protoDir)
	if err != nil {
		fatal("%v", err)
	}

	inv, err := filasDeInventario(*invPath)
	if err != nil {
		fatal("%v", err)
	}

	var problemas []string

	// --- 1 <-> 2: registro <-> .proto ---
	porTipo := map[string]tipoEvento{}
	for _, t := range s.Tipos {
		porTipo[t.Tipo] = t
	}

	// Índice mensaje -> tipo, derivado del registro con la misma conversión.
	// Así el checker no mantiene una segunda lista de nombres.
	porMensaje := map[string]string{}
	for _, t := range s.Tipos {
		want := mensajeDe(t.Tipo)
		porMensaje[want] = t.Tipo
		if _, ok := msgs[want]; !ok {
			problemas = append(problemas, fmt.Sprintf(
				"el registro declara el tipo %q pero no existe el mensaje %s en los .proto",
				t.Tipo, want))
		}
	}

	var sinRegistro []string
	for nombre := range msgs {
		if nombre == sobreEnvoltura {
			continue
		}
		if _, ok := porMensaje[nombre]; !ok {
			sinRegistro = append(sinRegistro, nombre)
		}
	}
	sort.Strings(sinRegistro)
	for _, nombre := range sinRegistro {
		problemas = append(problemas, fmt.Sprintf(
			"el mensaje %s existe en los .proto pero no tiene tipo de evento en el registro",
			nombre))
	}

	// --- 1 <-> 3: registro <-> INVENTARIO.md ---
	for _, t := range s.Tipos {
		f, ok := inv[t.Tipo]
		if !ok {
			problemas = append(problemas, fmt.Sprintf(
				"el registro declara el tipo %q pero INVENTARIO.md no lo lista", t.Tipo))
			continue
		}
		if f.version != t.Version {
			problemas = append(problemas, fmt.Sprintf(
				"%s: versión %d en el registro, %d en INVENTARIO.md",
				t.Tipo, t.Version, f.version))
		}
		if f.productor != t.Productor {
			problemas = append(problemas, fmt.Sprintf(
				"%s: productor %q en el registro, %q en INVENTARIO.md",
				t.Tipo, t.Productor, f.productor))
		}
		if !mismoConjunto(f.consumidores, t.ConsumidoresDurables) {
			problemas = append(problemas, fmt.Sprintf(
				"%s: consumidores %v en el registro, %v en INVENTARIO.md",
				t.Tipo, t.ConsumidoresDurables, f.consumidores))
		}
		if f.agregado != t.Agregado {
			problemas = append(problemas, fmt.Sprintf(
				"%s: agregado %q en el registro, %q en INVENTARIO.md",
				t.Tipo, t.Agregado, f.agregado))
		}
		if f.sensibilidad != t.Sensibilidad {
			problemas = append(problemas, fmt.Sprintf(
				"%s: sensibilidad %q en el registro, %q en INVENTARIO.md",
				t.Tipo, t.Sensibilidad, f.sensibilidad))
		}
	}

	for tipo := range inv {
		if _, ok := porTipo[tipo]; !ok {
			problemas = append(problemas, fmt.Sprintf(
				"INVENTARIO.md lista el tipo %q pero el registro no lo declara", tipo))
		}
	}

	if len(problemas) > 0 {
		sort.Strings(problemas)
		fmt.Fprintf(os.Stderr, "check-registro: el registro, los .proto y INVENTARIO.md NO coinciden:\n")
		for _, p := range problemas {
			fmt.Fprintf(os.Stderr, "  - %s\n", p)
		}
		os.Exit(1)
	}

	fmt.Printf("OK: registro, .proto e INVENTARIO.md coinciden (%d tipos de evento).\n", len(s.Tipos))
}

// mensajesDeProto recolecta los mensajes de nivel superior de todos los .proto.
func mensajesDeProto(dir string) (map[string]bool, error) {
	msgs := map[string]bool{}
	err := filepath.WalkDir(dir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || !strings.HasSuffix(path, ".proto") {
			return nil
		}
		raw, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		for _, m := range reMensaje.FindAllStringSubmatch(string(raw), -1) {
			msgs[m[1]] = true
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("no se pudieron leer los .proto: %w", err)
	}
	return msgs, nil
}

type filaInv struct {
	version      uint32
	productor    string
	consumidores []string
	agregado     string
	sensibilidad string
}

// filasDeInventario parsea la tabla de familias del INVENTARIO.md.
func filasDeInventario(path string) (map[string]filaInv, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("no se pudo abrir el inventario: %w", err)
	}
	defer f.Close()

	out := map[string]filaInv{}
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		m := reFilaInventario.FindStringSubmatch(strings.TrimSpace(sc.Text()))
		if m == nil {
			continue
		}
		var version uint32
		if _, err := fmt.Sscanf(m[2], "%d", &version); err != nil {
			continue
		}
		out[m[1]] = filaInv{
			version:      version,
			productor:    m[3],
			consumidores: tokensDe(m[4]),
			// La celda de agregado puede traer backticks y un `+` (p. ej.
			// `entidad` + `entidad_id`); se comparan sin markup.
			agregado:     strings.ReplaceAll(strings.TrimSpace(m[5]), "`", ""),
			sensibilidad: m[6],
		}
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("no se encontró ninguna fila en la tabla de %s", path)
	}
	return out, nil
}

// tokensDe extrae los identificadores entre backticks de una celda del inventario.
func tokensDe(celda string) []string {
	var out []string
	for _, m := range regexp.MustCompile("`([^`]+)`").FindAllStringSubmatch(celda, -1) {
		out = append(out, m[1])
	}
	return out
}

// mensajeDe traduce un tipo de evento canónico al nombre del mensaje Protobuf,
//PascalCase sobre TODAS sus partes (familia incluida):
//
//	viaje.estado_cambiado  -> ViajeEstadoCambiado
//	sesion.revocada       -> SesionRevocada
//	catalogo.actualizado   -> CatalogoActualizado
//
// La correspondencia es mecánica porque los .proto nombran el mensaje por la
// familia y el verbo, en el mismo idioma canónico (ADR 22). No hay tabla que
// mantener a mano.
func mensajeDe(tipo string) string {
	var b strings.Builder
	for _, parte := range strings.Split(tipo, ".") {
		for _, p := range strings.Split(parte, "_") {
			if p == "" {
				continue
			}
			b.WriteString(strings.ToUpper(p[:1]) + p[1:])
		}
	}
	return b.String()
}



// mismoConjunto compara dos listas sin importar el orden (el registro y el
// inventario pueden listar los consumidores en distinto orden).
func mismoConjunto(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	ma := append([]string(nil), a...)
	mb := append([]string(nil), b...)
	sort.Strings(ma)
	sort.Strings(mb)
	for i := range ma {
		if ma[i] != mb[i] {
			return false
		}
	}
	return true
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "check-registro: "+format+"\n", args...)
	os.Exit(1)
}