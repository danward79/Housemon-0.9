package decoders

import (
	"bytes"
	"encoding/binary"
	"github.com/jcw/flow"
)

func init() {
	flow.Registry["Node-emonLCD"] = func() flow.Circuitry { return &EmonLCD{} }
}

// Decoder for the "emonLCD" sketch. Registers as "Node-emonLCD".
type EmonLCD struct {
	flow.Gadget
	In  flow.Input
	Out flow.Output
}

type LCDData struct {
  Node  uint8
	Temp  uint16
  Light byte
}

// Start decoding emonLCD packets.
func (w *EmonLCD) Run() {
	for m := range w.In {
    
		if v, ok := m.([]byte); ok && len(v) == 4 {
			buf := bytes.NewReader(v)
			var data LCDData
			_ = binary.Read(buf, binary.LittleEndian, &data)
      
			m = map[string]int{
				"<reading>": 1,
				"temp":      int(data.Temp),
        "light":     int(255 - data.Light),
			}
		}

		w.Out.Send(m)
	}
}
