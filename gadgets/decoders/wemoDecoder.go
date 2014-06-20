package decoders

import (
	"bytes"
	"encoding/binary"
	"github.com/jcw/flow"
)

func init() {
	flow.Registry["Node-wemoStatus"] = func() flow.Circuitry { return &wemoStatus{} }
}

// Decoder for the "wemoStatus" sketch. Registers as "Node-wemoStatus".
type wemoStatus struct {
	flow.Gadget
	In  flow.Input
	Out flow.Output
}

type wemoData struct {
  Node    uint8
	Switch  uint16
}

// Start decoding emonLCD packets.
func (w *wemoStatus) Run() {
	for m := range w.In {
    
		if v, ok := m.([]byte); ok && len(v) == 4 {
			buf := bytes.NewReader(v)
			var data LCDData
			_ = binary.Read(buf, binary.LittleEndian, &data)
      
			m = map[string]int{
				"<reading>": 1,
				"switch":      int(data.Temp),
			}
		}

		w.Out.Send(m)
	}
}
