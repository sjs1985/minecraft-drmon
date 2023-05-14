-- created by acidjazz (https://github.com/acidjazz/drmon)
-- modified by sjs1985 (Risky version)

-- if both flux gates that are connected by modem you need to change these
-- otherwise the output flux gate needs to be on any side of the computer, and the input one will be searched for like normal
local inputGateName = "flux_gate_10"
local outputGateName = "flux_gate_11"
local bothGatesFound = false

-- modifiable variables
local reactorSide = "back"
local outputFluxGateSide = "right"

local targetStrength = 50
local targetTemperature = 7900
local maxTemperature = 8000
local safeTemperature = 6000
local maxOutput = 5e6
local lowestFieldPercent = 5

local activateOnCharged = 1

-- please leave things untouched from here on
os.loadAPI("lib/f")

local version = "0.25"
-- toggleable via the monitor, use our algorithm to achieve our target field strength or let the user tweak it
local autoInputGate = 1
local curInputGate = 222000

-- toggleable via the monitor, use our algorithm to auto increase reactor generation
local autoOutputGate = 0
local curOutputGate = 300000

-- monitor 
local mon, monitor, monX, monY

-- peripherals
local reactor
local outputFluxGate
local inputFluxGate

-- reactor information
local ri

-- last performed action
local action = "None since reboot"
local emergencyCharge = false
local emergencyTemp = false


m = peripheral.wrap("monitor_0")


monitor = f.periphSearch("monitor")

inputFluxGate = peripheral.wrap(inputGateName)
if inputFluxGate == null then
	inputFluxGate = f.periphSearch("flux_gate")
else
    outputFluxGate = peripheral.wrap(outputGateName)
	if outputFluxGate ~= null then
		bothGatesFound = true
	end
end


if peripheral.wrap("right") ~= null then
  if peripheral.getType("right") == "draconic_reactor" then
    reactorSide = "right"
   elseif bothGatesFound == false and peripheral.getType("right") == "flux_gate" then
    outputFluxGateSide = "right"
  end
end

if peripheral.wrap("left") ~= null then
  if peripheral.getType("left") == "draconic_reactor" then
    reactorSide = "left"
  elseif bothGatesFound == false and peripheral.getType("left") == "flux_gate" then
    outputFluxGateSide = "left"
  end
end

if peripheral.wrap("back") ~= null then
  if peripheral.getType("back") == "draconic_reactor" then
    reactorSide = "back"
  elseif bothGatesFound == false and peripheral.getType("back") == "flux_gate" then
    outputFluxGateSide = "back"
  end
end

if peripheral.wrap("top") ~= null then
  if peripheral.getType("top") == "draconic_reactor" then
    reactorSide = "top"
  elseif bothGatesFound == false and peripheral.getType("top") == "flux_gate" then
    outputFluxGateSide = "top"
  end
end

if peripheral.wrap("bottom") ~= null then
  if peripheral.getType("bottom") == "draconic_reactor" then
    reactorSide = "bottom"
  elseif bothGatesFound == false and peripheral.getType("bottom") == "flux_gate" then
    outputFluxGateSide = "bottom"
  end
end

if bothGatesFound == false then
    outputFluxGate = peripheral.wrap(outputFluxGateSide)
end

reactor = peripheral.wrap(reactorSide)

if monitor == null then
	error("No valid monitor was found")
end

if outputFluxGate == null then
	error("No valid output flux gate was found")
end

if reactor == null then
	error("No valid reactor was found")
end

if inputFluxGate == null then
	error("No valid input flux gate was found")
end

monX, monY = monitor.getSize()
mon = {}
mon.monitor,mon.X, mon.Y = monitor, monX, monY

--write settings to config file
function save_config()
  sw = fs.open("config.txt", "w")   
  sw.writeLine(version)
  sw.writeLine(autoInputGate)
  sw.writeLine(curInputGate)
  sw.writeLine(autoOutputGate)
  sw.writeLine(curOutputGate)
  sw.close()
end

--read settings from file
function load_config()
  sr = fs.open("config.txt", "r")
  version = sr.readLine()
  autoInputGate = tonumber(sr.readLine())
  curInputGate = tonumber(sr.readLine())
  autoOutputGate = tonumber(sr.readLine())
  curOutputGate = tonumber(sr.readLine())
  sr.close()
end


-- 1st time? save our settings, if not, load our settings
if fs.exists("config.txt") == false then
  save_config()
else
  load_config()
end

function buttons()

  while true do
    -- button handler
    event, side, xPos, yPos = os.pullEvent("monitor_touch")

    -- output gate controls
    -- 2-4 = -1000, 6-9 = -10000, 10-12,8 = -100000
    -- 17-19 = +1000, 21-23 = +10000, 25-27 = +100000
    if yPos == 8  and autoOutputGate == 0 then
      local cFlow = outputFluxGate.getSignalLowFlow()
      if xPos >= 2 and xPos <= 4 then
        cFlow = cFlow-1000
      elseif xPos >= 6 and xPos <= 9 then
        cFlow = cFlow-10000
      elseif xPos >= 10 and xPos <= 12 then
        cFlow = cFlow-100000
      elseif xPos >= 17 and xPos <= 19 then
        cFlow = cFlow+100000
      elseif xPos >= 21 and xPos <= 23 then
        cFlow = cFlow+10000
      elseif xPos >= 25 and xPos <= 27 then
        cFlow = cFlow+1000
      end
      outputFluxGate.setSignalLowFlow(cFlow)
    end
	
	-- output gate toggle
    if yPos == 8 and ( xPos == 14 or xPos == 15) then
      if autoOutputGate == 1 then
        autoOutputGate = 0
      else
        autoOutputGate = 1
      end
      save_config()
    end

    -- input gate controls
    -- 2-4 = -1000, 6-9 = -10000, 10-12,8 = -100000
    -- 17-19 = +1000, 21-23 = +10000, 25-27 = +100000
    if yPos == 10 and autoInputGate == 0 and xPos ~= 14 and xPos ~= 15 then
      if xPos >= 2 and xPos <= 4 then
        curInputGate = curInputGate-1000
      elseif xPos >= 6 and xPos <= 9 then
        curInputGate = curInputGate-10000
      elseif xPos >= 10 and xPos <= 12 then
        curInputGate = curInputGate-100000
      elseif xPos >= 17 and xPos <= 19 then
        curInputGate = curInputGate+100000
      elseif xPos >= 21 and xPos <= 23 then
        curInputGate = curInputGate+10000
      elseif xPos >= 25 and xPos <= 27 then
        curInputGate = curInputGate+1000
      end
      inputFluxGate.setSignalLowFlow(curInputGate)
      save_config()
    end

    -- input gate toggle
    if yPos == 10 and ( xPos == 14 or xPos == 15 ) then
      if autoInputGate == 1 then
        autoInputGate = 0
      else
        autoInputGate = 1
      end
      save_config()
    end
	
	-- power toggle
    if yPos == 3 and ( xPos >= 25 and xPos <= 27 ) then
        if ri.status == "stopping" or ri.status == "offline" then
			reactor.chargeReactor()
            action = "Manually started"
        end
        if ri.status == "online" or ri.status == "charging" then
            reactor.stopReactor()
            action = "Manually stopped"
        end
    end
  end
end

function drawButtons(y)

  -- 2-4 = -1000, 6-9 = -10000, 10-12,8 = -100000
  -- 17-19 = +1000, 21-23 = +10000, 25-27 = +100000

  f.draw_text(mon, 2, y, " < ", colors.white, colors.gray)
  f.draw_text(mon, 6, y, " <<", colors.white, colors.gray)
  f.draw_text(mon, 10, y, "<<<", colors.white, colors.gray)

  f.draw_text(mon, 17, y, ">>>", colors.white, colors.gray)
  f.draw_text(mon, 21, y, ">> ", colors.white, colors.gray)
  f.draw_text(mon, 25, y, " > ", colors.white, colors.gray)
end



function update()
  while true do 

    f.clear(mon)

    ri = reactor.getReactorInfo()

    -- print out all the infos from .getReactorInfo() to term

    if ri == nil then
      error("reactor has an invalid setup")
    end

    for k, v in pairs (ri) do
      print(k.. ": ".. tostring(v))
    end
    print("Output Gate: ", outputFluxGate.getSignalLowFlow())
    print("Input Gate: ", inputFluxGate.getSignalLowFlow())
    -- monitor output

    local statusColor
    statusColor = colors.red

    if ri.status == "online" or ri.status == "charged" then
      statusColor = colors.green
    elseif ri.status == "offline" then
      statusColor = colors.gray
    elseif ri.status == "charging" then
      statusColor = colors.orange
    end

	
    f.draw_text_lr(mon, 2, 2, 1, "Reactor Status", string.upper(ri.status), colors.white, statusColor, colors.black)
	f.draw_text(mon, 25, 3, " X ", colors.white, colors.gray)
    f.draw_text_lr(mon, 2, 4, 1, "Generation", f.format_int(ri.generationRate) .. " rf/t", colors.white, colors.lime, colors.black)

    local tempColor = colors.red
    if ri.temperature <= 5000 then tempColor = colors.green end
    if ri.temperature >= 5000 and ri.temperature <= 6500 then tempColor = colors.orange end
    f.draw_text_lr(mon, 2, 6, 1, "Temperature", f.format_int(ri.temperature) .. "C", colors.white, tempColor, colors.black)

    f.draw_text_lr(mon, 2, 7, 1, "Output Gate", f.format_int(outputFluxGate.getSignalLowFlow()) .. " rf/t", colors.white, colors.blue, colors.black)

    -- buttons
	if autoOutputGate == 1 then
      f.draw_text(mon, 14, 8, "AU", colors.white, colors.gray)
    else
      f.draw_text(mon, 14, 8, "MA", colors.white, colors.gray)
      drawButtons(8)
    end


    f.draw_text_lr(mon, 2, 9, 1, "Input Gate", f.format_int(inputFluxGate.getSignalLowFlow()) .. " rf/t", colors.white, colors.blue, colors.black)

    if autoInputGate == 1 then
      f.draw_text(mon, 14, 10, "AU", colors.white, colors.gray)
    else
      f.draw_text(mon, 14, 10, "MA", colors.white, colors.gray)
      drawButtons(10)
    end

    local satPercent
    satPercent = math.ceil(ri.energySaturation / ri.maxEnergySaturation * 10000)*.01

    f.draw_text_lr(mon, 2, 11, 1, "Energy Saturation", satPercent .. "%", colors.white, colors.white, colors.black)
    f.progress_bar(mon, 2, 12, mon.X-2, satPercent, 100, colors.blue, colors.gray)

    local fieldPercent, fieldColor
    fieldPercent = math.ceil(ri.fieldStrength / ri.maxFieldStrength * 10000)*.01

    fieldColor = colors.red
    if fieldPercent >= 50 then fieldColor = colors.green end
    if fieldPercent < 50 and fieldPercent > 30 then fieldColor = colors.orange end

    if autoInputGate == 1 then 
      f.draw_text_lr(mon, 2, 14, 1, "Field Strength T:" .. targetStrength, fieldPercent .. "%", colors.white, fieldColor, colors.black)
    else
      f.draw_text_lr(mon, 2, 14, 1, "Field Strength", fieldPercent .. "%", colors.white, fieldColor, colors.black)
    end
    f.progress_bar(mon, 2, 15, mon.X-2, fieldPercent, 100, fieldColor, colors.gray)

    local fuelPercent, fuelColor
	local fuelRate = ri.fuelConversionRate

    fuelPercent = 100 - math.ceil(ri.fuelConversion / ri.maxFuelConversion * 10000)*.01

    fuelColor = colors.red

    if fuelPercent >= 70 then fuelColor = colors.green end
    if fuelPercent < 70 and fuelPercent > 30 then fuelColor = colors.orange end

    f.draw_text_lr(mon, 2, 17, 1, "Fuel (".. fuelRate .. " nb/t)", fuelPercent .. "%", colors.white, fuelColor, colors.black)
    f.progress_bar(mon, 2, 18, mon.X-2, fuelPercent, 100, fuelColor, colors.gray)

    f.draw_text_lr(mon, 2, 19, 1, "Action ", action, colors.gray, colors.gray, colors.black)

    -- actual reactor interaction
    --
    if emergencyCharge == true then
      reactor.chargeReactor()
    end
    
    -- are we charging? open the floodgates
    if ri.status == "charging" then
      inputFluxGate.setSignalLowFlow(900000)
      emergencyCharge = false
    end

    -- are we stopping from a shutdown and our temp is better? activate
    if emergencyTemp == true and ri.status == "stopping" and ri.temperature < safeTemperature then
      reactor.activateReactor()
      emergencyTemp = false
    end

    -- are we charged? lets activate
    if ri.status == "charged" and activateOnCharged == 1 then
      reactor.activateReactor()
    end

    -- are we on? regulate the input flux gate to our target field strength
    -- or set it to our saved setting since we are on manual
	-- also regulate the output flux gate if set to auto
    if ri.status == "online" then
      if autoInputGate == 1 then 
        fluxval = ri.fieldDrainRate / (1 - (targetStrength/100) )
        print("Target Gate: ".. fluxval)
        inputFluxGate.setSignalLowFlow(fluxval)
      else
        inputFluxGate.setSignalLowFlow(curInputGate)
      end
	  
	  if autoOutputGate == 1 then 
	    -- this is copied math - I take no resposibility for it being correct :)
		local cFlow  = math.max( 0, math.min( (targetTemperature - ri.temperature) * 200, -( 8 - fieldPercent ) * 1e6 ) + ri.generationRate )
        print("Output Gate: ".. cFlow)
        outputFluxGate.setSignalLowFlow( math.min( maxOutput, cFlow ) )
      end
    end

    -- safeguards
    --
    
    -- out of fuel, kill it
    if fuelPercent <= 10 then
      reactor.stopReactor()
      action = "Fuel below 10%, refuel"
    end

    -- field strength is too dangerous, kill and it try and charge it before it blows
    if fieldPercent <= lowestFieldPercent and ri.status == "online" then
      action = "Field Str < " ..lowestFieldPercent.."%"
      reactor.stopReactor()
      reactor.chargeReactor()
      emergencyCharge = true
    end

    -- temperature too high, kill it and activate it when its cool
    if ri.temperature > maxTemperature then
      reactor.stopReactor()
      action = "Temp > " .. maxTemperature
      emergencyTemp = true
    end

    sleep(0.1)
  end
end

parallel.waitForAny(buttons, update)