function configure()
    -----------------------------------------------
    --   Smart  Home  System  by  FishingHacks   --
    -----------------------------------------------


    -----------------------------------------------
    --        C O N F I G U R A T I O N          --
    -----------------------------------------------

    --- What this Device should show up as
    device_name = "speaker"
    --- The players allowed to use this
    --- format: ({name="password", ...})
    --- example: {FishingHacks="password"}
    players = { FishingHacks = "password" }
    --- The Port to transmit data on
    --- you probably want to keep this be 69
    port = 69
    --- What side the modem is attached on
    --- top, bottom, left, right, front or back
    --- example: "top"
    modem_side = "bottom"

    toggle_redstone("lights toggle", "right", 15, 0)

    register_command("stop music", function(player, id)
        call_on_all_devices(peripheral.wrap("back"), "speaker", "playSound", "")
        call_on_all_devices(peripheral.wrap("back"), "monitor", "clear")
    end)

    register_command("play", function(player, id)
        local input = read_user_input(player, id, "music:\n", 1902, 15)
        if input ~= nil then
            if ("" .. input):len() < 1 or ("" .. input) == "" then
                broadcast(player, id, "Cancelled Input")
            else
                broadcast(player, id, "Playing " .. input)
                call_on_all_devices(peripheral.wrap("back"), "monitor", "clear")
                call_on_all_devices(peripheral.wrap("back"), "monitor", "setCursorPos", 1, 1)
                call_on_all_devices(peripheral.wrap("back"), "monitor", "write", "Playing Sound:")
                call_on_all_devices(peripheral.wrap("back"), "monitor", "setCursorPos", 1, 2)
                call_on_all_devices(peripheral.wrap("back"), "monitor", "write", "" .. input)
                call_on_all_devices(peripheral.wrap("back"), "speaker", "playSound", "" .. input)
            end
        end
    end)

    register_command("play disc", function(player, id)
        local input = read_user_input(player, id, "disc:\n", 1902, 15)
        if input ~= nil then
            if ("" .. input):len() < 1 or ("" .. input) == "" then
                broadcast(player, id, "Cancelled Input")
            else
                broadcast(player, id, "Playing " .. input)
                call_on_all_devices(peripheral.wrap("back"), "monitor", "clear")
                call_on_all_devices(peripheral.wrap("back"), "monitor", "setCursorPos", 1, 1)
                call_on_all_devices(peripheral.wrap("back"), "monitor", "write", "Playing Music Disc:")
                call_on_all_devices(peripheral.wrap("back"), "monitor", "setCursorPos", 1, 2)
                call_on_all_devices(peripheral.wrap("back"), "monitor", "write", "" .. input)
                call_on_all_devices(peripheral.wrap("back"), "speaker", "playSound", "minecraft:music_disc." .. input)
            end
        end
    end)

    ---------------------------------------------
end

--[[
        Protocol Specifications
        Yes I know the password can be spoofed, but im not gonna implement encryption

        Packet:
        | Device Name | Player Name | Password | Packet Type | ID | <...data>
        Default Port: 69

        PTC: Player to Computer (the player sends these packets)
        CTP: Computer to Player (the computer sends these packets)

        Packet Type:
        "L": PTC. List devices (all devices that this player can access should respond with an R packet). Data: None. ID doesn't matter. Device Name doesn't matter.
        "R": CTP. List Devices Response. Data: A List of all valid commands. ID doesn't matter.
        "C": PTC. Command. Data: Command Name and the ID going forward. ID doesn't matter.
        "I": CTP. Asks the Player for Input. Data: Input Question (iex. Password) and the ID
        "S": PTC. Send Input. Data: The Input and the ID
        "N": CTP. Sends a notification to the client. Data: Notification Text (iex. Wrong Password)
        "A": PTC. Notifies the Computer that the client closed connection.
        "D": CTP. Notifies the Player that the command finished.



        Note: The Packet does not *actually* contain hyphons, but rather each field is a fixed length or contains some data to dictate that length.
        Lengths:
          - Strings: A Number at the start of the field dictates the length
          - Numbers: 2 Bytes Long
          - Lists: Has at the start a number of elements, the total size is the size of each element combined. Each Element is a String.
          - Packet Type: 1 Byte
    ]]
--

cur_event_data = nil
coroutines = {}
always_running_routines = {}
commands = {}

function main()
    term.clear()
    term.setCursorPos(1, 1)
    draw_titlebar("Startup")
    if device_name == nil or device_name:len() < 1 or device_name == "" then
        error("no device name specified")
    end

    if not table_has_elements(players) then
        warn("The Playertable is empty. This way, players cannot interact with this device")
    end

    if peripheral.getType(modem_side) ~= "modem" then
        error("Could not find modem")
    end
    modem = peripheral.wrap(modem_side) or error("Could not find modem")
    modem.open(port)

    term.write("Commands: ")
    local command_entries = table_entries(commands);
    for i = 1, #command_entries do
        term.write(command_entries[i])
        if i < #command_entries then
            term.write(", ")
        end
    end
    print()

    while true do
        if #always_running_routines + #table_entries(coroutines) > 0 then
            os.startTimer(0.5)
        end
        local data = { os.pullEventRaw() }
        local event = data[1]

        if event == "terminate" then
            -- exit
            for k, v in pairs(coroutines) do
                send_packet(v[2], "D", k)
            end
            return
        elseif event == "modem_message" then
            -- we don't handle a different response channel
            if data[3] == port and data[3] == data[4] then
                local success, packet_type, id, player, data = pcall(process_packet, "" .. data[5], true)
                if not success then
                    warn("Failed to process packet: " .. packet_type)
                end
                if packet_type == "C" then
                    -- Issued a command
                    local command_name = data[1]
                    local success, id = pcall(tonumber, data[2])
                    if command_name ~= nil and success and commands[command_name] ~= nil then
                        if coroutines[id] == nil then
                            local thread = coroutine.create(commands[command_name]);
                            print("Running Command " .. command_name)
                            coroutine.resume(thread, player, id)
                            coroutines[id] = { thread, player, "" }
                        end
                    end
                elseif packet_type == "A" then
                    -- Abort a coroutine
                    local id = data[0]
                    if coroutines[id] ~= nil then
                        coroutines[id] = nil
                    end
                elseif packet_type == "L" then
                    print(player .. " asks for commands")
                    send_packet(player, "R", 0, table.unpack(table_entries(commands)))
                end
                os.queueEvent("packet_received", packet_type, id, player, data)
            end
        else
            cur_event_data = data
            -- run all the coroutines
            for i = 1, #always_running_routines do
                if coroutine.status(always_running_routines[i][1]) ~= "dead" then
                    if cur_event_data[1] == always_running_routines[i][2] then
                        local success, err = coroutine.resume(always_running_routines[i][1],
                            table.unpack(cur_event_data, 1))
                        if success then
                            always_running_routines[i][2] = err
                        else
                            warn("A coroutine crashed: " .. err)
                        end
                    else
                        local success, err = coroutine.resume(always_running_routines[i][1])
                        if success then
                            always_running_routines[i][2] = err
                        else
                            warn("A coroutine crashed: " .. err)
                        end
                    end
                end
            end
            for k, v in pairs(coroutines) do
                if coroutine.status(v[1]) == "dead" then
                    coroutines[k] = nil
                    send_packet(v[2], "D", k)
                    print("Finished running " .. k)
                else
                    if cur_event_data[1] == coroutines[k][3] then
                        local success, err = coroutine.resume(coroutines[k][1], table.unpack(cur_event_data, 1))
                        if success then
                            coroutines[k][3] = err
                        else
                            print("running " .. k .. " failed")
                            print("Err: " .. err)
                            send_packet(v[2], "D", k)
                            coroutines[k] = nil
                        end
                    else
                        local success, err = coroutine.resume(coroutines[k][1])
                        if success then
                            coroutines[k][3] = err
                        else
                            print("running " .. k .. " failed")
                            print("Err: " .. err)
                            send_packet(v[2], "D", k)
                            coroutines[k] = nil
                        end
                    end
                end
            end
            -- done
            cur_event_data = nil
        end

        local num_threads = #table_entries(coroutines)
        draw_titlebar("Currently Running Threads: " ..
        (num_threads + #always_running_routines) .. " (" .. num_threads .. "/" .. #always_running_routines .. ")")
    end
end

function read_user_input(player, id, prompt, input_id, timeout)
    local input_id = "" .. input_id
    send_packet(player, "I", id, "" .. prompt, input_id)
    -- wait for response
    local start = os.clock()
    while true do
        if timeout ~= nil and os.clock() - start >= timeout then
            -- nil = timeout
            return nil
        end
        data = get_event()
        if data[1] == "packet_received" and data[2] == "S" and data[3] == id and data[4] == player and data[5][2] == input_id then
            return data[5][1]
        end
    end
end

function broadcast(player, id, text)
    send_packet(player, "N", id, text .. "\n")
end

function trigger_redstone(command, side, length, strength_on, strength_off)
    redstone.setAnalogOutput(side, strength_off)
    register_command(command, function()
        redstone.setAnalogOutput(side, strength_on)
        sleep(length)
        redstone.setAnalogOutput(side, strength_off)
    end)
end

function toggle_redstone(command, side, strength_on, strength_off, initial_value)
    if initial_value == true then
        redstone.setAnalogOutput(side, strength_on)
    else
        redstone.setAnalogOutput(side, strength_off)
    end
    register_command(command, function()
        if redstone.getAnalogInput(side) == strength_on then
            redstone.setAnalogOutput(side, strength_off)
        else
            redstone.setAnalogOutput(side, strength_on)
        end
    end)
end

function set_redstone(command, side, strength)
    register_command(command, function ()
        redstone.setAnalogOutput(side, strength)
    end)
end

function wait_for_event_of_type(type)
    while true do
        local event = get_event()
        if event[0] == type then
            return event
        end
    end
end

function event_claim()
    cur_event_data = nil
end

function get_event()
    coroutine.yield()
    return cur_event_data
end

function register_coroutine(fn, ...)
    local thread = coroutine.create(fn)
    coroutine.resume(thread, ...)
    always_running_routines[#always_running_routines + 1] = { thread, "" }
end

function register_command(cmd, fn)
    if cmd == "back" or cmd == "exit" then
        error("the command cannot be back or exit")
    end
    commands[cmd] = fn
end

function send_packet(player, type, id, ...)
    if players[player] == nil then return end
    local data = { ... }
    local str = write_str(device_name) ..
        write_str(player) .. write_str(players[player]) .. type .. write_u16(id) .. write_list(data)

    modem.transmit(port, port, str)
end

function process_packet(str, is_computer)
    local buffer = StringBuffer:new(str)
    local p_dev_name = read_str(buffer)
    local player = read_str(buffer)
    local password = read_str(buffer)
    local packet_type = buffer:read(1):upper()

    if (p_dev_name ~= device_name and packet_type ~= "L") then
        return error("not this device")
    end
    -- if the player doesnt have access or the password doesnt match
    if players[player] == nil or players[player] ~= password then
        return error("player and password combinations are wrong")
    end

    -- check if packet is for you
    -- CTP: R, I, N, D
    -- PTC: L, C, S, A
    local is_ctp = packet_type == "R" or packet_type == "I" or packet_type == "N" or packet_type == "D"
    local is_ptc = packet_type == "L" or packet_type == "C" or packet_type == "S" or packet_type == "A"
    -- unknown packet type
    if not is_ctp and not is_ptc then error("unknown packet type") end
    if is_computer == is_ptc then
        -- the packet *is* correct
        local id = read_u16(buffer)
        local data = read_list(buffer)

        return packet_type, id, player, data
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
        str = str .. write_str("" .. list[i])
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

function dbg(thing)
    print(textutils.serialise(thing))
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

configure()
main()
