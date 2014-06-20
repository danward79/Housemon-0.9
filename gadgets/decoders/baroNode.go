// Decoder for the "BMP085demo.ino" sketch as in: http://github.com/jcw/jeelib/tree/master/examples/Ports/bmp085demo/bmp085demo.ino
// Decoder Registers as "Node-Bmp085".
//
// Tweaked version of TheDistractors Code. Added Light level and battery voltage packets. 
package decoders

import (
	"bytes"
	"encoding/binary"
	"github.com/jcw/flow"
)

func init() {
	flow.Registry["Node-baro"] = func() flow.Circuitry { return &BaroNode{} }
}

type BaroNode struct {
	flow.Gadget
	In  flow.Input
	Out flow.Output
}

type BaroData struct {
	Node  uint8
  Light byte
	Temp  uint16
	Press uint32
  Battery uint16
}


func (w *BaroNode) Run() {

	for m := range w.In {

		if v, ok := m.([]byte); ok && len(v) >= 8 {
			buf := bytes.NewReader(v)
			var data BaroData
			_ = binary.Read(buf, binary.LittleEndian, &data)

			m = map[string]int{
				"<reading>": 1,
        "light":     int(data.Light),
				"temp":      int(data.Temp),
				"pressure":  int(data.Press),
        "battery":  int(data.Battery),
			}
		}
    
		w.Out.Send(m)
	}
}
