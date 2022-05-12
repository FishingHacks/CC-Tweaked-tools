local modem = peripheral.find("modem") or error("No modem found!", 0)

function string.starts(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end

function string.split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

local completion = require "cc.completion"
write("Send or Receive? ")
local options = { "send", "receive" }
local s = string.lower(read(nil, nil, function(text) return completion.choice(text, options) end))
if s == "send" then
    local f = read("filename")
   local pass = read("password")
   send(pass, f)
elseif s == "receive" then
    local pass = read("password")
    receive(pass)
else
    error("Operation not known", 0)
end

function send(pwd, file)
    if string.match(file, "#") then
        error("filename includes #")
        return false
    end
    if string.starts("pwd", "ack") then
        error("Password can't start with ack")
        return false
    end
    print("sending file...")
    if not fs.exists(file) then
        error("File " .. file .. " doesn't exist", 0)
        return false
    end
    modem.transmit(46, 46, pwd .. "#" .. file .. "#".. fs.open(file, "r").readAll())
    print("file send...")
    print("waiting for received acknowledgement...")
    modem.open(46)
    local event, side, channel, replyChannel, message, distance
    repeat
        event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    until channel == 46 and string.starts(message, "ack"..pwd)
    modem.close(46)
    print("File received...")
    return true
end

function receive(pwd)
    if string.starts("pwd", "ack") then
        error("Password can't start with ack")
        return false
    end
    modem.open(46)
    local event, side, channel, replyChannel, message, distance
    print("Waiting for file...")
    repeat
        event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    until channel == 46 and string.starts(message, pwd)
    modem.close(46)
    local filename = string.split(message, "#")[2]
    local contents = string.split(message, "#")[3]
    print("received " .. filename)
    fs.open(filename, "w").write(contents)
    print("wrote contents")
    print("sending received acknowledgement")
    modem.transmit(46, 0, "ack"..pwd)
end
