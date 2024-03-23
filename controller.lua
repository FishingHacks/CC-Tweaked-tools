--------------------------
--  Smart Home  System  --
--   by  FishingHacks   --
--------------------------
--     CONFIGURATION    --
--------------------------

-- your player name
player_name =
"FishingHacks"
-- your password
password =
"password"
--the port your controller
--works on. You usually
--wanna leave this as is
port = 69

--------------------------


if peripheral.getType("back") ~= "modem" then
    error("Could not get access to the modem")
end
modem = peripheral.wrap("back") or error("Could not get access to the modem")
modem.open(port)

completion = require("cc.completion")

function main()
    term.clear()
    term.setCursorPos(1,1)
    draw_titlebar("Collecting Commands")
    local commands = retrieve_commands()
    local devices = table_entries(commands)
    devices[#devices + 1] = "exit"
    devices[#devices + 1] = "back"

    while true do
        term.clear()
        term.setCursorPos(1, 1)
        draw_titlebar("Select Device")

        print("Devices:")
        for i = 1, #devices - 2 do
            print(devices[i])
        end
        local device = get_valid_result("dev", devices, "Select Device")
        if device == "exit" or device == "back" then
            return
        end
        if commands[device] ~= nil then
            while true do
                term.clear()
                term.setCursorPos(1, 1)
                draw_titlebar("Device: " .. device)
                print("Commands:")
                for i = 1, #commands[device] - 2 do
                    print(commands[device][i])
                end
                local command = get_valid_result("func", commands[device], "Device: " .. device)
                if command == "back" then
                    break
                end
                if command == "exit" then
                    return
                end
                if table.contains(commands[device], command) then
                    local old = new_window()
                    term.clear()
                    term.setCursorPos(1, 1)

                    draw_titlebar("Running: " .. command)

                    send_packet(device, "C", os.getComputerID(), command, "" .. os.getComputerID())

                    parallel.waitForAny(
                        applyfn(wait_for_packet, "D", os.getComputerID(), device),
                        applyfn(command_environment, device, os.getComputerID())
                    )
                    term.redirect(old)
                end
            end
        end
    end
end

function draw_titlebar(text)
    local x, y = term.getCursorPos()
    if y == 1 then y = 2 end
    local bg = term.getBackgroundColor()
    local fg = term.getTextColor()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.yellow)
    term.setTextColor(colors.black)
    term.clearLine()
    term.setCursorPos(1, 1)
    write(text)
    term.setCursorPos(x, y)
    term.setTextColor(fg)
    term.setBackgroundColor(bg)
end

function new_window()
    local cur = term.current()
    local w, h = term.getSize()
    term.redirect(window.create(term.current(), 1, 1, w, h))
    return cur
end

function applyfn(fn, ...)
    local args = { ... }

    return function()
        return fn(table.unpack(args))
    end
end

function command_environment(device, id)
    while true do
        local data = { os.pullEventRaw() }
        local event = data[1]

        if event == "terminate" then
            send_packet(device_name, "A", id)
            return
        elseif event == "modem_message" then
            local success, p_type, p_id, p_device_name, data = pcall(process_packet, "" .. data[5], false)
            if success and p_device_name == device and p_id == id then
                if p_type == "N" and data[1] ~= nil then
                    write(data[1])
                elseif p_type == "D" then
                    return
                elseif p_type == "I" and data[1] ~= nil and data[2] ~= nil then
                    write(data[1])
                    local val = read()
                    coroutine.yield() -- to check that we're really still supposed to run
                    send_packet(device, "S", id, val, data[2])
                end
            end
        end
    end
end

function get_valid_result(name, results, titlebar)
    local value = ""
    while true do
        draw_titlebar(titlebar)
        write(name)
        write(": ")
        value = read(nil, nil, function(text) return completion.choice(text, results) end, value)
        if table.contains(results, value) then return value end
    end
end

function retrieve_commands()
    send_packet("", "L", 0)
    local time_start = os.clock()
    local devices = {}

    os.startTimer(1)
    while (os.clock() - time_start) < 1 do
        local type, _, device_name, commands = wait_for_packet("R", nil, nil)
        if type == nil then
            break
        end
        commands[#commands + 1] = "back"
        commands[#commands + 1] = "exit"
        devices[device_name] = commands
    end
    return devices
end

function wait_for_packet(type, id, device_name)
    while true do
        local data = { os.pullEventRaw() }
        if data[1] == "terminate" or data[1] == "timer" then
            return nil
        elseif data[1] == "modem_message" then
            if data[3] == port and data[3] == data[4] then
                local success, p_type, p_id, p_device_name, data = pcall(process_packet, "" .. data[5], false)
                if not success then
                    warn("Failed to process packet: " .. p_type)
                end

                if (p_type == type or p_type == nil) and (id == p_id or id == nil) and (device_name == p_device_name or device_name == nil) then
                    return p_type, p_id, p_device_name, data
                end
            end
        end
    end
end

function send_packet(device_name, type, id, ...)
    local data = { ... }
    local str = write_str(device_name) ..
        write_str(player_name) .. write_str(password) .. type .. write_u16(id) .. write_list(data)

    modem.transmit(port, port, str)
end

function process_packet(str, is_computer)
    local buffer = StringBuffer:new(str)
    local device_name = read_str(buffer)
    -- if the player doesnt have access or the password doesnt match
    if read_str(buffer) ~= player_name or read_str(buffer) ~= password then
        return error("player and password combinations are wrong")
    end

    -- check if packet is for you
    -- CTP: R, I, N, D
    -- PTC: L, C, S, A
    local packet_type = buffer:read(1):upper()
    local is_ctp = packet_type == "R" or packet_type == "I" or packet_type == "N" or packet_type == "D"
    local is_ptc = packet_type == "L" or packet_type == "C" or packet_type == "S" or packet_type == "A"
    -- unknown packet type
    if not is_ctp and not is_ptc then error("unknown packet type") end
    if is_computer == is_ptc then
        -- the packet *is* correct
        local id = read_u16(buffer)
        local data = read_list(buffer)

        return packet_type, id, device_name, data
    end
    return nil
end

function write_str(str)
    return write_u16(str:len()) .. str
end

function read_str(buffer)
    return buffer:read(read_u16(buffer))
end

function write_list(list)
    local str = write_u16(#list)
    for i = 1, #list do
        str = str .. write_str(list[i])
    end
    return str
end

function read_list(buffer)
    local len = read_u16(buffer)
    local list = {}
    for i = 1, len do
        list[i] = read_str(buffer)
    end
    return list
end

function write_u16(u16)
    if u16 > 0xffff then error("Value was greater than 16 bits") end
    return string.pack("BB", bit.band(u16, 0xff), bit.brshift(u16, 8))
end

function read_u16(buffer)
    if buffer:len() < 2 then
        error("Value was less than 16 bits")
    end
    local a, b = string.unpack("BB", buffer:read(2))
    return bit.bor(a, bit.blshift(b, 8))
end

function call_on_all_devices(modem, dev, func, ...)
    if modem.isWireless() then
        error("the modem is wireless")
    end
    local my_name = modem.getNameLocal()
    local devices = modem.getNamesRemote()
    for i = 1, #devices do
        local dev_name = devices[i]
        if dev_name ~= my_name and modem.hasTypeRemote(dev_name, dev) then
            modem.callRemote(dev_name, func, ...)
        end
    end
end

function table_has_elements(t)
    local fn, tbl, idx = pairs(t)
    return fn(tbl, idx) ~= nil
end

function warn(message)
    local color = term.getTextColor()
    term.setTextColor(colors.orange)
    print(message)
    term.setTextColor(color)
end

StringBuffer = { index = 1, str = "" }

function StringBuffer:new(str)
    o = {}
    setmetatable(o, { __index = self })
    o.str = str
    o.index = 1
    return o
end

function StringBuffer:len()
    return self.str:len() - self.index + 1
end

function StringBuffer:read(bytes)
    local value = self.str:sub(self.index, self.index + bytes - 1)
    self.index = self.index + bytes
    return value
end

function table_entries(table)
    local values = {}
    for k, _ in pairs(table) do
        values[#values + 1] = k
    end
    return values
end

function table_entries(table)
    local values = {}
    for k, _ in pairs(table) do
        values[#values + 1] = k
    end
    return values
end

function dbg(thing)
    print(textutils.serialise(thing))
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

main()
