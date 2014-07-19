//Package to interface to Wemo devices
package wemo

import (
  "github.com/jcw/flow"
  "github.com/golang/glog"
  "github.com/savaki/go.wemo" 
  "fmt"
  "strings"
  "log"
  "time"
  "strconv"
)

func init() {
	glog.Infoln("Wemo Gadget Init...")
	flow.Registry["WemoSubscribe"] = func() flow.Circuitry { return new(WemoSubscribe) }
  flow.Registry["WemoDeviceAction"] = func() flow.Circuitry { return new(WemoDeviceAction) }
  flow.Registry["WemoDeviceStatus"] = func() flow.Circuitry { return new(WemoDeviceStatus) }
  flow.Registry["WemoMap"] = func() flow.Circuitry { return &WemoMap{} }
}


// This gadget subscribes to Wemo events and manages subscriptions
// Needs a callback IP Address:Port, a subscription timeout and outputs the state of the device.
type WemoSubscribe struct {
	flow.Gadget
  EthInterface flow.Input
  Address flow.Input
  Timeout flow.Input
  Out flow.Output
}

func (g *WemoSubscribe) Run() {
 
  var listenerAddress string = ""
  var timeout int
  var ethInterface string = ""
  
  for m := range g.Address{
    listenerAddress = m.(string)
  }

  for m := range g.Timeout {
    timeout, _ = strconv.Atoi(m.(string))
  }
  
  for m := range g.EthInterface{
    ethInterface = m.(string)
  }
  
  api, _ := wemo.NewByInterface(ethInterface)
  
  devices, _ := api.DiscoverAll(3*time.Second)
 
  subscriptions := make(map[string]*wemo.SubscriptionInfo)

  for _, device := range devices {
    _, err := device.ManageSubscription(listenerAddress, timeout, subscriptions)
    if err != 200 {
      log.Println("Initial Error Subscribing: ", err)   
    }
  }
  
  cs := make(chan wemo.SubscriptionEvent)

  go wemo.Listener(listenerAddress, cs)

  for m := range cs{
    if _, ok := subscriptions[m.Sid]; ok {
      subscriptions[m.Sid].State = m.State
      output := fmt.Sprintf("Switch:%v, %v = %v", subscriptions[m.Sid].FriendlyName, subscriptions[m.Sid].Host, subscriptions[m.Sid].State)
      g.Out.Send(output)
    }
  }  
  
}


//This gadget carries out an action and needs an IP Address, an action and a trigger
type WemoDeviceAction struct {
	flow.Gadget
  Address flow.Input
  Action flow.Input
  Trigger flow.Input
}

func (g *WemoDeviceAction) Run() {
 
  var action, address string = "", ""
	
  for m := range g.Action{
    action = m.(string)
  }
  
  for m := range g.Address{
    address = m.(string)
  }

  for m := range g.Trigger {
    glog.Infoln("Wemo Action Trigger:- ", m, ", Address:- ", address, " Action:- ", action)
    
    device := &wemo.Device{Host: address}

    switch action {
    case "Toggle":
      device.Toggle()
    case "Off":
      device.Off()
    case "On":
      device.On()        
    }
  }
}

//This gadget quieries state and needs an IP Address, a trigger and outputs the state of the device.
type WemoDeviceStatus struct {
	flow.Gadget
  Address flow.Input
  Trigger flow.Input
  Out flow.Output
}

func (g *WemoDeviceStatus) Run() {
 
  var address string = ""
  var state int = 0
  
  for m := range g.Address{
    address = m.(string)
  }

  for m := range g.Trigger {
    glog.Infoln("Wemo Status Trigger:- ", m, ", Address:- ", address)

    device  := &wemo.Device{Host: address}
    state = device.GetBinaryState()
    
    output := fmt.Sprintf("switch:%s %d", address, state)
    
    g.Out.Send(output)
  }
}

// Lookup information to determine what decoder to use.
// Registers as "NodeMap".
type WemoMap struct {
	flow.Gadget
	Info flow.Input
	In   flow.Input
	Out  flow.Output
}

// Start looking up node ID's in the node map.
func (w *WemoMap) Run() {
	nodeMap := map[string]string{}
	locations := map[string]string{}
	for m := range w.Info {
		f := strings.Split(m.(string), ",")
		nodeMap[f[0]] = f[1]
    fmt.Println(nodeMap)
		if len(f) > 2 {
			locations[f[0]] = f[2]
      fmt.Println(locations)
		}
	}

	var group int
	for m := range w.In {
		w.Out.Send(m)
    fmt.Println("M: ", m)
		if data, ok := m.(map[string]int); ok {
      fmt.Println("Data: ", data)
			switch {
			case data["<RF12demo>"] > 0:
				group = data["group"]
			case data["<node>"] > 0:
				key := fmt.Sprintf("RFg%di%d", group, data["<node>"])
				if loc, ok := locations[key]; ok {
					w.Out.Send(flow.Tag{"<location>", loc})
				}
				if tag, ok := nodeMap[key]; ok {
					w.Out.Send(flow.Tag{"<dispatch>", tag})
				}
			}
		}
	}
}
