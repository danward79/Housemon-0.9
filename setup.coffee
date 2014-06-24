#!/usr/bin/env coffee

circuits = {}

# jeebus setup, stores in db and publishes on mqtt
circuits.main =
  gadgets: [
    { name: "http", type: "HTTPServer" }
    { name: "init", type: "init" }
  ]
  feeds: [
    { tag: "/", data: "./app",  to: "http.Handlers" }
    { tag: "/base/", data: "./base",  to: "http.Handlers" }
    { tag: "/ws", data: "<websocket>",  to: "http.Handlers" }
    { data: ":3000",  to: "http.Port" }
  ]

# init circuit for HouseMon, which starts its own http server.
circuits.init =
  gadgets: [
    { name: "mqtt", type: "MQTTServer" }
		# { name: "replay", type: "replay" }
    { name: "sub", type: "DataSub" }
    { name: "pub", type: "MQTTPub" }
    { name: "dummy", type: "Pipe" } # needed for dispatcher in HouseMon
    { name: "driverFill", type: "driverFill" } # pre-load the database
    { name: "tableFill", type: "tableFill" }   # pre-load the database
    { name: "sub2", type: "DataSub" }
    { name: "aggr", type: "Aggregator" }
    { name: "db", type: "LevelDB" }
    { name: "serial", type: "serial" }
   # { name: "wemo", type: "wemo" }
   # { name: "demo", type: "demo" }
  ]
  wires: [
    { from: "mqtt.PortOut", to: "pub.Port" }
    { from: "sub.Out", to: "pub.In" }
    { from: "sub2.Out", to: "aggr.In" }
    { from: "aggr.Out", to: "db.In" }
  ]
  feeds: [
    { data: ":1883",  to: "mqtt.Port" }
    { data: "/",  to: "sub.In" }
    { data: "sensor/",  to: "sub2.In" }
    # { data: "1m",  to: "aggr.Step" }
  ]
  labels: [
    { external: "In", internal: "dummy.In" }
    { external: "Out", internal: "dummy.Out" }
  ]

# define the websocket handler using a loop in and out of RpcHandler
circuits["WebSocket-jeebus"] =
  gadgets: [
    { name: "rpc", type: "RpcHandler" }
  ]
  labels: [
    { external: "In", internal: "rpc.In" }
    { external: "Out", internal: "rpc.Out" }
  ]

# this app runs a replay simulation with dynamically-loaded decoders
circuits.replay =
  gadgets: [
    { name: "lr", type: "LogReader" }
    { name: "rf", type: "Pipe" } # used to inject an "[RF12demo...]" line
    { name: "w1", type: "LogReplayer" }
    { name: "ts", type: "TimeStamp" }
    { name: "f1", type: "FanOut" }
    { name: "lg", type: "Logger" }
    { name: "db", type: "rf12toDatabase" }
  ]
  wires: [
    { from: "lr.Out", to: "w1.In" }
    { from: "rf.Out", to: "ts.In" }
    { from: "w1.Out", to: "ts.In" }
    { from: "ts.Out", to: "f1.In" }
    { from: "f1.Out:lg", to: "lg.In" }
    { from: "f1.Out:db", to: "db.In" }
  ]
  feeds: [
    { data: "[RF12demo.10] _ i31* g212 @ 433 MHz", to: "rf.In" }
    { data: "./gadgets/rfdata/20121130.txt", to: "lr.Name" } #20121130 20131218
    { data: "./logger", to: "lg.Dir" }
  ]
  
# the node mapping for nodes at JeeLabs, as pre-configured circuit
circuits.nodesJeeLabs =
  gadgets: [
    { name: "nm", type: "NodeMap" }
  ]
  feeds: [
    { data: "RFg5i2,roomNode,boekenkast JC",    to: "nm.Info" }
    { data: "RFg5i3,radioBlip,werkkamer",       to: "nm.Info" }
    { data: "RFg5i4,roomNode,washok",           to: "nm.Info" }
    { data: "RFg5i5,roomNode,woonkamer",        to: "nm.Info" }
    { data: "RFg5i6,roomNode,hal vloer",        to: "nm.Info" }
    { data: "RFg5i9,homePower,meterkast",       to: "nm.Info" }
    { data: "RFg5i10,roomNode,hal voor",        to: "nm.Info" }
    { data: "RFg5i11,roomNode,logeerkamer",     to: "nm.Info" }
    { data: "RFg5i12,roomNode,boekenkast L",    to: "nm.Info" }
    { data: "RFg5i13,roomNode,raam halfhoog",   to: "nm.Info" }
    { data: "RFg5i14,otRelay,zolderkamer",      to: "nm.Info" }
    { data: "RFg5i15,smaRelay,washok",          to: "nm.Info" }
    { data: "RFg5i18,p1scanner,meterkast",      to: "nm.Info" }
    { data: "RFg5i19,ookRelay,werkkamer",       to: "nm.Info" }
    { data: "RFg5i23,roomNode,gang boven",      to: "nm.Info" }
    { data: "RFg5i24,roomNode,zolderkamer",     to: "nm.Info" }
    
    { data: "RFg212i11,emonLCD,bedroom",        to: "nm.Info" }
    { data: "RFg212i16,outdoorClimate,balcony", to: "nm.Info" }
    { data: "RFg212i17,baro,lounge",            to: "nm.Info" }
  ]
  labels: [
    { external: "In", internal: "nm.In" }
    { external: "Out", internal: "nm.Out" }
  ]

# pipeline used for decoding RF12demo data and storing it in the database
circuits.rf12toDatabase =
  gadgets: [
    { name: "st", type: "SketchType" }
    { name: "d1", type: "Dispatcher" }
    { name: "nm", type: "nodesJeeLabs" }
    { name: "d2", type: "Dispatcher" }
    { name: "rd", type: "Readings" }
    { name: "ss", type: "PutReadings" }
    { name: "f2", type: "FanOut" }
    { name: "sr", type: "SplitReadings" }
    { name: "db", type: "LevelDB" }
  ]
  wires: [
    { from: "st.Out", to: "d1.In" }
    { from: "d1.Out", to: "nm.In" }
    { from: "nm.Out", to: "d2.In" } 
    
    # 2014-05-18 19:58:45.781146327 +1000 EST
    # map[<node>:11]
    # {Tag:<location> Msg:bedroom}
    # {Tag:<dispatch> Msg:emonLCD}
    # [11 233 8 255]
       
    { from: "d2.Out", to: "rd.In" }
    
    # 2014-05-18 20:00:25.795893693 +1000 EST
    # map[<node>:11]
    # {Tag:<location> Msg:bedroom}
    # map[<reading>:1 temp:2287 light:0]
    
    { from: "rd.Out", to: "ss.In" }
    
    # map[asof:2014-05-18 20:07:35.858844062 +1000 EST decoder:emonLCD rf12:map[<RF12demo>:12 band:433 group:212 id:31] node:map[<node>:11] location:bedroom reading:map[temp:2300 light:0] other:[[31 116 20 7 9]]]
     
    { from: "ss.Out", to: "f2.In" }
    
    # {Tag:/reading/RF12:212:11 Msg:map[ms:1400407795879 val:map[temp:2293 light:0] loc:bedroom typ:emonLCD id:RF12:212:11]}
    
    { from: "f2.Out:sr", to: "sr.In" }
    
    # {Tag:/reading/RF12:212:11 Msg:map[ms:1400407885892 val:map[temp:2300 light:0] loc:bedroom typ:emonLCD id:RF12:212:11]}
    
    { from: "f2.Out:db", to: "db.In" }
    
    # {Tag:/reading/RF12:212:11 Msg:map[ms:1400408035916 val:map[temp:2300 light:0] loc:bedroom typ:emonLCD id:RF12:212:11]}
    
    { from: "sr.Out", to: "db.In" }
  ]
  feeds: [
    { data: "Sketch-", to: "d1.Prefix" }
    { data: "Node-", to: "d2.Prefix" }
  ]
  labels: [
    { external: "In", internal: "st.In" }
  ]

# serial port test
circuits.serial =
  gadgets: [
    { name: "sp", type: "SerialPort" }
    { name: "ts", type: "TimeStamp" }
    { name: "f1", type: "FanOut" }
    { name: "lg", type: "Logger" }
    { name: "db", type: "rf12toDatabase" }
  ]
  wires: [
    { from: "sp.From", to: "ts.In" }
    { from: "ts.Out", to: "f1.In" }
    { from: "f1.Out:lg", to: "lg.In" }
    { from: "f1.Out:db", to: "db.In" }
  ]
  feeds: [
    { data: "/dev/ttyUSB0", to: "sp.Port" }
    { data: "./logger", to: "lg.Dir" }
  ]

# Wemo mapping for devices at djw's place, as pre-configured circuit
# circuits.wemoMap =
#  gadgets: [
#    { name: "wm", type: "WemoMap" }
#  ]
#  feeds: [
#    { data: "192.168.0.14:49153,switch,Wendys Balls",  to: "wm.Info" }
#    { data: "192.168.0.15:49153,switch,Lounge Lamp",   to: "wm.Info" }
#  ]
#  labels: [
#    { external: "In", internal: "wm.In" }
#    { external: "Out", internal: "wm.Out" }
#  ]
# wemo test
#circuits.wemo =
#  gadgets: [
#    { name: "c", type: "Clock" }
#    { name: "f1", type: "FanOut" }
#    { name: "wa", type: "WemoDeviceAction" }
#    { name: "ws", type: "WemoDeviceStatus" }
#    { name: "d", type: "Delay"}
#    { name: "ts", type: "TimeStamp"}
#    { name: "pr", type: "Printer"}
#    { name: "f2", type: "FanOut" }
#    { name: "lg", type: "Logger" }
#    { name: "wm", type: "wemoMap" }
#  ]
#  wires: [
#    { from: "c.Out", to: "f1.In" }
#    { from: "f1.Out:wa", to: "wa.Trigger" }
#    { from: "f1.Out:d", to: "d.In" }
#    { from: "d.Out", to: "ws.Trigger" }
#    { from: "ws.Out", to: "ts.In" }
#    { from: "ts.Out", to: "f2.In" }
#    { from: "f2.Out:nm", to: "wm.In" }
#    { from: "f2.Out:lg", to: "lg.In" }
#    { from: "wm.Out", to: "pr.In" }    
#  ]
#  feeds: [
#    { data: "20s", to: "c.In" }
#    { data: "192.168.0.15:49153", to: "wa.Address" }
#    { data: "192.168.0.15:49153", to: "ws.Address" }
#    { data: "None", to: "wa.Action"}
#    { data: "1s", to: "d.Delay"}
#    { data: "./wemologger", to: "lg.Dir" }
#  ]

# jeeboot server test
circuits.jeeboot =
  gadgets: [
    { name: "sp", type: "SerialPort" }
    { name: "rf", type: "Sketch-RF12demo" }
    { name: "sk", type: "Sink" }
    { name: "jb", type: "JeeBoot" }
  ]
  wires: [
    { from: "sp.From", to: "rf.In" }
    { from: "rf.Out", to: "sk.In" }
    { from: "rf.Rej", to: "sk.In" }
    { from: "rf.Oob", to: "jb.In" }
    { from: "jb.Out", to: "sp.To" }
  ]
  feeds: [
    { data: "/dev/tty.usbserial-A6666KGL", to: "sp.Port" }
  ]

    
# simple never-ending demo
circuits.demo =
  gadgets: [
    { name: "c", type: "Clock" }
    { name: "p", type: "Printer" }
  ]
  wires: [
    {from: "c.Out", to: "p.In"}
  ]
  feeds: [
    { data: "10s", to: "c.In" }
  ]
  
# pre-load some driver info into the database
circuits.driverFill =
  gadgets: [
    { name: "db", type: "LevelDB" }
  ]
  feeds: [
    { to: "db.In", tag: "/driver/roomNode/temp", \
      data: { name: "Temperature", unit: "°C", scale: 1 } }
    { to: "db.In", tag: "/driver/roomNode/humi", \
      data: { name: "Humidity", unit: "%" } }
    { to: "db.In", tag: "/driver/roomNode/light", \
      data: { name: "Light intensity", unit: "%", factor: 0.392, scale: 0 } }
    { to: "db.In", tag: "/driver/roomNode/moved", \
      data: { name: "Motion", unit: "(0/1)" } }
      
    { to: "db.In", tag: "/driver/smaRelay/yield", \
      data: { name: "PV daily yield", unit: "kWh", scale: 3 } }
    { to: "db.In", tag: "/driver/smaRelay/dcv1", \
      data: { name: "PV level east", unit: "V", scale: 2 } }
    { to: "db.In", tag: "/driver/smaRelay/dcv2", \
      data: { name: "PV level west", unit: "V", scale: 2 } }
    { to: "db.In", tag: "/driver/smaRelay/acw", \
      data: { name: "PV power AC", unit: "W" } }
    { to: "db.In", tag: "/driver/smaRelay/dcw1", \
      data: { name: "PV power east", unit: "W" } }
    { to: "db.In", tag: "/driver/smaRelay/dcw2", \
      data: { name: "PV power west", unit: "W" } }
    { to: "db.In", tag: "/driver/smaRelay/total", \
      data: { name: "PV total", unit: "MWh", scale: 3 } }
      
    { to: "db.In", tag: "/driver/homePower/c1", \
      data: { name: "Counter stove", unit: "kWh", factor: 0.5, scale: 3 } }
    { to: "db.In", tag: "/driver/homePower/p1", \
      data: { name: "Usage stove", unit: "W", scale: 1 } }
    { to: "db.In", tag: "/driver/homePower/c2", \
      data: { name: "Counter solar", unit: "kWh", factor: 0.5, scale: 3 } }
    { to: "db.In", tag: "/driver/homePower/p2", \
      data: { name: "Production solar", unit: "W", scale: 1 } }
    { to: "db.In", tag: "/driver/homePower/c3", \
      data: { name: "Counter house", unit: "kWh", factor: 0.5, scale: 3 } }
    { to: "db.In", tag: "/driver/homePower/p3", \
      data: { name: "Usage house", unit: "W", scale: 1 } }
      
    { to: "db.In", tag: "/driver/emonLCD/temp", \
      data: { name: "Temperature", unit: "°C", scale: 2 } }
    { to: "db.In", tag: "/driver/emonLCD/light", \
      data: { name: "Light Intensity", unit: "%", factor: 0.392, scale: 0 } }
    
    { to: "db.In", tag: "/driver/outdoorClimate/light", \
      data: { name: "Light intensity", unit: "%", factor: 0.392, scale: 0 } }
    { to: "db.In", tag: "/driver/outdoorClimate/humi", \
      data: { name: "Humidity", unit: "%", scale: 1 } }
    { to: "db.In", tag: "/driver/outdoorClimate/temp", \
      data: { name: "Temperature", unit: "°C", scale: 1 } }
    { to: "db.In", tag: "/driver/outdoorClimate/battery", \
      data: { name: "Battery", unit: "mV", scale: 0 } }
      
    { to: "db.In", tag: "/driver/baro/light", \
      data: { name: "Light intensity", unit: "%", factor: 0.392, scale: 0 } }
    { to: "db.In", tag: "/driver/baro/temp", \
      data: { name: "Temperature", unit: "°C", scale: 1 } }
    { to: "db.In", tag: "/driver/baro/pressure", \
      data: { name: "Pressure", unit: "mPA", scale: 2 } }
    { to: "db.In", tag: "/driver/baro/battery", \
      data: { name: "Battery", unit: "mV", scale: 0 } }
      
    { to: "db.In", tag: "/driver/wemo/switch", \
      data: { name: "Switch", unit: "(0/1)" } }
  ]
  
# pre-load some table info into the database
circuits.tableFill =
  gadgets: [
    { name: "db", type: "LevelDB" }
  ]
  feeds: [
    { to: "db.In", tag: "/table/table", data: { attr: "id attr" } }
    { to: "db.In", tag: "/column/table/id", data: { name: "Ident" } }
    { to: "db.In", tag: "/column/table/attr", data: { name: "Attributes" } }

    { to: "db.In", tag: "/table/column", data: { attr: "id name" } }
    { to: "db.In", tag: "/column/column/id", data: { name: "Ident" } }
    { to: "db.In", tag: "/column/column/name", data: { name: "Name" } }

    { to: "db.In", tag: "/table/driver", data: { attr: "id name unit factor scale" } }
    { to: "db.In", tag: "/column/driver/id", data: { name: "Parameter" } }
    { to: "db.In", tag: "/column/driver/name", data: { name: "Name" } }
    { to: "db.In", tag: "/column/driver/unit", data: { name: "Unit" } }
    { to: "db.In", tag: "/column/driver/factor", data: { name: "Factor" } }
    { to: "db.In", tag: "/column/driver/scale", data: { name: "Scale" } }

    { to: "db.In", tag: "/table/reading", data: { attr: "id loc val ms typ" } }
    { to: "db.In", tag: "/column/reading/id", data: { name: "Ident" } }
    { to: "db.In", tag: "/column/reading/loc", data: { name: "Location" } }
    { to: "db.In", tag: "/column/reading/val", data: { name: "Values" } }
    { to: "db.In", tag: "/column/reading/ms", data: { name: "Timestamp" } }
    { to: "db.In", tag: "/column/reading/typ", data: { name: "Type" } }
  ]

# trial circuit
circuits.try1 =
  gadgets: [
    { name: "db", type: "LevelDB" }
  ]
  feeds: [
    { tag: "<range>", data: "/reading/", to: "db.In" }
  ]

# write configuration to file, but keep a backup of the original, just in case
fs = require 'fs'
try fs.renameSync 'setup.json', 'setup-prev.json'
fs.writeFileSync 'setup.json', JSON.stringify circuits, null, 4
