package decoders

import (
	"github.com/jcw/flow"
)

func init() {
	flow.Registry["Node-outdoorClimate"] = func() flow.Circuitry { return &OutdoorClimate{} }
}

// Decoder for the "OutdoorClimate" sketch. Registers as "Node-outdoorClimate".
type OutdoorClimate struct {
	flow.Gadget
	In  flow.Input
	Out flow.Output
}

// Start decoding OutdoorClimate packets.
//struct {byte light; int humidity; int temperature; byte vcc; } payload;
func (w *OutdoorClimate) Run() {
	for m := range w.In {
		if v, ok := m.([]byte); ok && len(v) >= 6{
			m = map[string]int{
				"<reading>": 1,
        "light":  int(v[1]),
        "humi":   int(v[2])+ (256 * int(v[3])),
				"temp":   int(v[4])+ (256 * int(v[5])),
        "battery": (int(v[6]) * 20) + 1000,
			}
		}

		w.Out.Send(m)
	}
}
