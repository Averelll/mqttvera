

module("L_Mqtthandler", package.seeall)

-- Service ID strings used by this device.
SERVICE_ID = "urn:upnp-mqtthandler-se:serviceId:Mqtthandler"

-- define variables --

local mqttServerIp = nil
local mqttServerPort = 0

local MQTT = require("mqtt_library")

	package.loaded.JSON = nil
	json = require("JSON")


local MQTTHANDLER_LOG_NAME = "Mqtthandler plugin: "

-- define functions --

local function log(text, level)
	luup.log("Mqtthandler plugin: " .. text, (level or 50))
	end

function mqttsend(mqttdata)
	luup.log(MQTTHANDLER_LOG_NAME .. "Publish MQTT message: " .. mqttdata, 1)
	mqtt_client:publish("Event/Vera", mqttdata)
end

function mqttcallback (topic, payload)
	luup.log(MQTTHANDLER_LOG_NAME .. "Enter readFromMqtt", 1)
	luup.log(topic .. ":" .. payload,1)
	local testj = json:decode(payload)
	if luup.devices[tonumber(testj.id)].category_num == 17 then
		luup.variable_set("urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", testj.temperature, tonumber(testj.id))
	end
	if luup.devices[tonumber(testj.id)].category_num == 16 then
		luup.log("humidity")
		luup.log(testj.humidity)
		luup.variable_set("urn:micasaverde-com:serviceId:HumiditySensor1", "CurrentLevel", testj.humidity, tonumber(testj.id))
	end
	if luup.devices[tonumber(testj.id)].category_num == 5 then
		luup.log("heater")
--		luup.log(testj.humidity)
		luup.variable_set("urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", testj.temperature, tonumber(testj.id))
		luup.variable_set("urn:upnp-org:serviceId:TemperatureSetpoint1_Heat", "CurrentSetpoint", testj.setpoint, tonumber(testj.id))
	end
	luup.log(luup.devices[tonumber(testj.id)].category_num)
	luup.log(testj.id)
end

function startup(lul_device)

	-- let's first handle the child device --

	child_devices = luup.chdev.start(lul_device);

	luup.chdev.append(lul_device, child_devices, "T1", "Bathroom", "urn:schemas-micasaverde-com:device:TemperatureSensor:1", "D_TemperatureSensor1.xml", "", "urn:upnp-org:serviceId:TemperatureSensor1,CurrentTemperature=0", true)
	luup.chdev.append(lul_device, child_devices, "Phigh", "Power High", "urn:schemas-micasaverde-com:device:PowerMeter:1", "D_PowerMeter1.xml", "", "urn:micasaverde-com:serviceId:EnergyMetering1,KWH=1331.1", true)
	luup.chdev.append(lul_device, child_devices, "Plow", "Power Low", "urn:schemas-micasaverde-com:device:PowerMeter:1", "D_PowerMeter1.xml", "", "urn:micasaverde-com:serviceId:EnergyMetering1,KWH=1331.23", true)
	luup.chdev.append(lul_device, child_devices, "Blind 1","Rolluiken boven links","urn:schemas-micasaverde-com:device:WindowCovering:1","D_WindowCovering1.xml","","",false)
	luup.chdev.append(lul_device, child_devices, "Blind 2","Rolluiken boven rechts","urn:schemas-micasaverde-com:device:WindowCovering:1","D_WindowCovering1.xml","","",false)
	luup.chdev.append(lul_device, child_devices, "T2", "Temperature Shed", "urn:schemas-micasaverde-com:device:TemperatureSensor:1", "D_TemperatureSensor1.xml", "", "urn:upnp-org:serviceId:TemperatureSensor1,CurrentTemperature=0", true)
	luup.chdev.append(lul_device, child_devices, "Blind 3","Rolluiken keuken","urn:schemas-micasaverde-com:device:WindowCovering:1","D_WindowCovering1.xml","","",false)
	luup.chdev.append(lul_device, child_devices, "Hum 1", "Humidity Shed","urn:micasaverde-com:serviceId:HumiditySensor1", "D_HumiditySensor1.xml", "S_HumiditySensor1.xml", "", true)
	luup.chdev.append(lul_device, child_devices, "Heat 1", "Thermostat kitchen","urn:schemas-upnp-org:device:Heater:1", "D_Heater1.xml", "", "", true)
	luup.chdev.sync(lul_device,child_devices)

-- We want to watch all zwave switches and dimmers --

for deviceNo,d in pairs(luup.devices) do
	if d.device_num_parent == 1 then
		luup.log('===>Device # ' .. deviceNo .. ' id: ' .. d.id .. ' name: ' .. d.description .. ' type: ' .. d.device_type .. ' category: ' .. d.category_num)
		if d.category_num == 2 then 
			-- dimmer --
			luup.variable_watch("watchVariable", "urn:upnp-org:serviceId:Dimming1", "LoadLevelStatus", deviceNo)	
		end
		if d.category_num == 3 then 
			-- switch --
			luup.variable_watch("watchVariable", "urn:upnp-org:serviceId:SwitchPower1", "Status", deviceNo)
		end
	end
end
luup.variable_watch("watchVariable", "urn:upnp-org:serviceId:SwitchPower1", "Status", 58)

	_G["sendToMqtt"] = sendToMqtt
	_G["startMqtt"] = startMqtt
	_G["mqttcallback"] = mqttcallback
	_G["watchVariable"] = watchVariable


	MQTTHANDLER_DEVICE = lul_device
	log("Initialising Mqtthandler", 1)

	--Reading variables --
	mqttServerIp = luup.variable_get(SERVICE_ID, "mqttServerIp", MQTTHANDLER_DEVICE)
	if(mqttServerIp == nil) then
		mqttServerIp = "192.168.0.70"
		luup.variable_set(SERVICE_ID, "mqttServerIp", mqttServerIp, MQTTHANDLER_DEVICE)
	end
	
	mqttServerPort = luup.variable_get(SERVICE_ID, "mqttServerPort", MQTTHANDLER_DEVICE)
	if(mqttServerPort == nil) then
		mqttServerPort = "1883"
		luup.variable_set(SERVICE_ID, "mqttServerPort", mqttServerPort, MQTTHANDLER_DEVICE)
	end
	log("Start - Preparing worker thread", 1)
	-- Prepare the worker "thread"
	luup.call_delay("startMqtt", 20, "")
	log("Done - Preparing worker thread", 1)
end

function startMqtt(luup_data)

	luup.log(MQTTHANDLER_LOG_NAME .. "Enter startMqtt", 1)
	luup.log(MQTTHANDLER_LOG_NAME .. "Create MQTT Client", 1)
	luup.log(MQTTHANDLER_LOG_NAME .. "Connect to " .. mqttServerIp .. " and port " .. mqttServerPort, 1)
	mqtt_client = MQTT.client.create(mqttServerIp, mqttServerPort, mqttcallback)
	
	luup.log(MQTTHANDLER_LOG_NAME .. "Connect MQTT Client", 1)
	mqtt_client:connect("Vera")
	luup.log(MQTTHANDLER_LOG_NAME .. "declare topics", 1)
	topics = {}
	luup.log(MQTTHANDLER_LOG_NAME .. "set topics[1]", 1)
	luup.log(MQTTHANDLER_LOG_NAME .. "Subscribe to Update/Vera", 1)
	mqtt_client:subscribe({"Update/Vera"})
	luup.log(MQTTHANDLER_LOG_NAME .. "call_delay", 1)
	luup.call_delay("sendToMqtt", 10, "")

end

function sendToMqtt(luup_data)
	
	luup.log(MQTTHANDLER_LOG_NAME .. "Publish MQTT message", 1)
	mqtt_client:publish("Vera/Test", "*** Vera test start ***")
	mqtt_client:handler("")
		
	luup.call_delay("sendToMqtt", 5, "")
	luup.log(MQTTHANDLER_LOG_NAME .. "Leaving sendToMqtt", 1)
end

function watchVariable(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	luup.log(MQTTHANDLER_LOG_NAME .. "Device: " .. lul_device .. " Variable: " .. lul_variable .. " Value " .. lul_value_old .. " => " .. lul_value_new, 1)
		local json_string = "{\"id\": " ..lul_device .. ", \"variable\": \"" .. lul_variable .. "\", \"newvalue\": " .. lul_value_new .. "}"
	mqtt_client:publish("Event/Vera", json_string)
end


