function call(event, identifier, payload, modem, port)
    if not payload == "" then
        payload="#"..payload
    end
    modem.transmit(port, 0, "shs#" .. event .. "#" .. identifier .. payload)
end

function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

function starts(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end


function receive(event, identifier, modem)
    modem.open(43)
    local event, side, channel, replyChannel, message, distance
    repeat
        event, side, channel, replyChannel, message = os.pullEvent("modem_message")
    until channel == 43 and starts(message, "shs#"..event.."#"..identifier)
    return split(message, "#")[5] or ""
end

function getTraffic(identifier, modem)
    modem.open(43)
    local event, side, channel, replyChannel, message, distance
    repeat
        event, side, channel, replyChannel, message = os.pullEvent("modem_message")
    until channel == 43 and split(message, "#")[3]==identifier
    return {split(message, "#")[2], (split(message, "#")[5] or "")}
end
