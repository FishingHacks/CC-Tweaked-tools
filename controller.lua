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
--"gui", "text", "select"
ui_type = "gui"
--------------------------
-- Quick Select Config  --
--------------------------
-- cmd="device"
quick_select_config =
{
    ["lights toggle"] = "speaker",
    ["play disc"] = "speaker",
    ["alarm"] = "speaker",
}
--------------------------


if ui_type ~= "select" and ui_type ~= "gui" and ui_type ~= "text" then
    error("ui_type has to be:\n\"gui\", \"text\" or \"select\"")
end


if peripheral.getType("back") ~= "modem" then
    error("Could not get access to the modem")
end
modem = peripheral.wrap("back") or error("Could not get access to the modem")
modem.open(port)

completion = require("cc.completion")

function retrieve_from_list_fn(name, items, titlebar)
    if ui_type == "gui" or ui_type == "select" then
        return render_gui(items, titlebar)
    else
        return get_valid_result(name, items, titlebar)
    end
end

function main()
    term.clear()
    term.setCursorPos(1, 1)
    draw_titlebar("Collecting Commands")
    local commands = retrieve_commands()
    local devices = table_entries(commands)
    devices[#devices + 1] = "exit"
    devices[#devices + 1] = "back"

    while true do
        term.clear()
        term.setCursorPos(1, 1)
        draw_titlebar("Select Device")

        local device = retrieve_from_list_fn("dev", devices, "Select Device")
        if device == nil or device == "exit" or device == "back" then
            return
        elseif commands[device] ~= nil then
            while true do
                term.clear()
                term.setCursorPos(1, 1)
                draw_titlebar("Device: " .. device)
                local command = retrieve_from_list_fn("func", commands[device], "Device: " .. device)
                if command == nil or command == "exit" then
                    return
                elseif command == "back" then
                    break
                elseif table.contains(commands[device], command) then
                    local old = new_window()
                    term.clear()
                    term.setCursorPos(1, 1)

                    draw_titlebar("Running: " .. command)

                    send_packet(device, "C", os.getComputerID(), command, "" .. os.getComputerID())

                    parallel.waitForAny(
                        applyfn(wait_for_command_end, device, os.getComputerID()),
                        applyfn(command_environment, device, os.getComputerID(), command)
                    )
                    term.redirect(old)
                end
            end
        end
    end
end

function main_quickselect()
    local commands = table_entries(quick_select_config)
    commands[#commands + 1] = "exit"

    while true do
        term.clear()
        term.setCursorPos(1, 1)
        draw_titlebar("Select Command")

        local command = render_gui(commands, "Select Command")
        if command == "exit" then
            return
        elseif quick_select_config[command] ~= nil then
            local device = quick_select_config[command]

            local old = new_window()
            term.clear()
            term.setCursorPos(1, 1)

            draw_titlebar("Running: " .. command)

            send_packet(device, "C", os.getComputerID(), command, "" .. os.getComputerID())

            parallel.waitForAny(
                applyfn(wait_for_command_end, device, os.getComputerID()),
                applyfn(command_environment, device, os.getComputerID(), command)
            )
            term.redirect(old)
        end
    end
end

function render_gui(items, titlebar)
    local fg = term.getTextColor()
    local bg = term.getBackgroundColor()
    term.clear()
    term.setCursorPos(1, 1)
    draw_titlebar(titlebar)
    local w, h = term.getSize()
    local scroll_y = render_gui_frame(items, {}, initial_scroll_y or 0, 1, 3, w, h - 3)

    while true do
        local event = { os.pullEventRaw() }
        if event == "terminate" then
            term.setTextColor(fg)
            term.setBackgroundColor(bg)
            term.clear()
            term.setCursorPos(1, 1)
            return nil
        end
        local w, h = term.getSize()
        paintutils.drawFilledBox(1, 1, w + 1, h + 1, colors.black)
        term.setCursorPos(1, 1)
        draw_titlebar(titlebar)
        local new_scroll_y, clicked = render_gui_frame(items, event, scroll_y, 1, 3, w, h - 3)
        scroll_y = new_scroll_y
        if clicked ~= nil then
            term.setBackgroundColor(bg)
            term.setTextColor(fg)
            term.clear()
            term.setCursorPos(1, 1)
            return clicked
        end
    end
end

function render_gui_frame(items, event, scroll_y, x, y, w, h)
    local scroll_y = scroll_y

    if event[1] == "mouse_scroll" and event[3] >= x and event[3] < x + w and event[4] >= y and event[4] < y + h then
        local max_height = math.max(#items * 4 - h, 0)

        scroll_y = math.max(scroll_y + event[2], 0)
        if scroll_y > max_height then scroll_y = max_height end
    end

    local clicked_btn = nil

    if event[1] == "mouse_up" then
        local mouse_x = event[3]
        local mouse_y = event[4]
        if mouse_x >= x and mouse_x < x + w and mouse_y >= y and mouse_y < y + h then
            -- is in-bounds
            local local_x = mouse_x - x
            local local_y = mouse_y - y
            if local_x ~= 0 and local_x < w - 2 then
                for i = 1, #items do
                    if is_in_bounds(local_x, local_y, 2, i * 4 - 4 - scroll_y, w - 2, 3) then
                        clicked_btn = items[i]
                    end
                end
            end
        end
    end

    for i = 1, #items do
        local btn_y = i * 4 - 4 - scroll_y + y
        render_button(items[i], x + 1, btn_y, w - 2, 3, x, y, x + w, y + h)
    end

    return scroll_y, clicked_btn
end

function is_in_bounds(pos_x, pos_y, rect_x, rect_y, rect_w, rect_h)
    return pos_x >= rect_y and pos_y >= rect_y and pos_x < rect_x + rect_w and pos_y < rect_y + rect_h
end

function draw_text_centered(text, x, y, width, color)
    local fg = term.getTextColor()
    if color ~= nil then
        term.setTextColor(color)
    end
    local x = x + math.floor((width - #text) / 2)
    term.setCursorPos(x, y)
    term.write(text)
    term.setTextColor(fg)
end

function render_button(text, x, y, w, h, bounds_x, bounds_y, bounds_end_x, bounds_end_y)
    if x + w <= bounds_x or y + h <= bounds_y or x >= bounds_end_x or y >= bounds_end_y then return end
    local start_x = math.max(x, bounds_x)
    local start_y = math.max(y, bounds_y)
    local end_x = math.min(x + w - 1, bounds_end_x - 1)
    local end_y = math.min(y + h - 1, bounds_end_y - 1)
    -- local start_x = x
    -- local start_y = y
    -- local end_x = x + w - 1
    -- local end_y = y + h - 1
    if start_x > end_x or start_y > end_y then return end
    paintutils.drawFilledBox(start_x, start_y, end_x, end_y, colors.green)
    local text_y_off = math.floor((h - 1) / 2) + y
    if text_y_off >= bounds_y and text_y_off < bounds_end_y then
        draw_text_centered(text, x + 2, text_y_off, w - 4, colors.black)
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

function wait_for_command_end(device, id)
    wait_for_packet("D", id, device)
    write("Finished...\n")
    os.sleep(0.5)
end

function command_environment(device_name, id, command)
    while true do
        local data = { os.pullEventRaw() }
        local event = data[1]

        if event == "terminate" then
            send_packet(device_name, "A", id)
            return
        elseif event == "modem_message" then
            local success, p_type, p_id, p_device_name, data = pcall(process_packet, "" .. data[5], false)
            if success and p_device_name == device_name and p_id == id then
                if p_type == "N" and data[1] ~= nil then
                    write(data[1])
                elseif p_type == "D" then
                    os.sleep(0.5)
                    return
                elseif p_type == "E" then
                    term.clear()
                    term.setCursorPos(1, 1)
                elseif p_type == "I" and data[1] ~= nil and data[2] ~= nil then
                    write(data[1])
                    local val = read()
                    coroutine.yield() -- to check that we're really still supposed to run
                    send_packet(device_name, "S", id, val, data[2])
                end
            end
        end

        draw_titlebar("Running: " .. command)
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
    local is_ctp = packet_type == "R" or packet_type == "I" or packet_type == "N" or packet_type == "D" or
    packet_type == "E"
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

if ui_type == "select" then
    main_quickselect()
else
    main()
end
