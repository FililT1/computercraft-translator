-- Requires python server running on 5002 port, which can be downloaded from
-- http://github.com/FililT1/computercraft-translator/

SpeedOS.ToolBarColour = colours.black
SpeedOS.ToolBarTextColour = colours.white

SpeedOS.LoadAPI("SpeedAPI/_paintutils")

local server = "http://127.0.0.1:5002/translate"

while true do
    -- Funkciya dlya deserializacii JSON
    function deserializeJSON(json)
        local function parseValue(str)
            str = str:match("^%s*(.-)%s*$")
            
            if str:sub(1, 1) == '"' then
                return str:match('^"(.-)"'), str:match('^".-"(.*)')
            end
            
            local num = str:match("^-?%d+%.?%d*")
            if num then
                return tonumber(num), str:sub(#num + 1)
            end

            if str:sub(1, 4) == "true" then
                return true, str:sub(5)
            elseif str:sub(1, 5) == "false" then
                return false, str:sub(6)
            end

            if str:sub(1, 4) == "null" then
                return nil, str:sub(5)
            end

            if str:sub(1, 1) == "[" then
                local arr = {}
                str = str:sub(2)
                while str:sub(1, 1) ~= "]" do
                    local value
                    value, str = parseValue(str)
                    table.insert(arr, value)
                    str = str:match("^%s*,%s*(.-)$") or str
                end
                return arr, str:sub(2)
            end

            if str:sub(1, 1) == "{" then
                local obj = {}
                str = str:sub(2)
                while str:sub(1, 1) ~= "}" do
                    local key
                    key, str = parseValue(str)
                    str = str:match("^%s*:%s*(.-)$")
                    local value
                    value, str = parseValue(str)
                    obj[key] = value
                    str = str:match("^%s*,%s*(.-)$") or str
                end
                return obj, str:sub(2)
            end

            return nil, str
        end

        local result, remaining = parseValue(json)
        if remaining:match("%S") then
            return nil, "Oshibka parsinga JSON: nekorrektnyj format"
        end
        return result
    end

    -- Funkciya dlya serializacii JSON
    function serializeJSON(tbl)
        local function serializeValue(value)
            if type(value) == "string" then
                return '"' .. value:gsub('"', '\\"') .. '"'
            elseif type(value) == "number" or type(value) == "boolean" then
                return tostring(value)
            elseif type(value) == "table" then
                local isArray = true
                local count = 0
                for k, _ in pairs(value) do
                    count = count + 1
                    if type(k) ~= "number" then
                        isArray = false
                    end
                end

                local result = {}
                if isArray then
                    for i = 1, count do
                        table.insert(result, serializeValue(value[i]))
                    end
                    return "[" .. table.concat(result, ",") .. "]"
                else
                    for k, v in pairs(value) do
                        table.insert(result, '"' .. k .. '":' .. serializeValue(v))
                    end
                    return "{" .. table.concat(result, ",") .. "}"
                end
            else
                return 'null'
            end
        end
        return serializeValue(tbl)
    end

    -- Funkciya perevoda
    function translate(text, source, target)
        local request = {
            text = text,
            source = source,
            target = target
        }

        local json = serializeJSON(request)
        local response = http.post(server, json, { ["Content-Type"] = "application/json" })

        if response then
            local responseText = response.readAll()
            response.close()
            local result = deserializeJSON(responseText)

            if result and result.translated_text then
                return result.translated_text
            else
                return "Oshibka perevoda"
            end
        else
            return "Oshibka soedineniya s serverom"
        end
    end

    -- Ochistka ekrana i ustanovka cvetov
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setTextColor(colors.white)

    -- Vvod teksta
    term.setCursorPos(3, 2)
    term.write("Enter source text: ")
    term.setCursorPos(3, 3)
    local text = read()

    -- Vvod iskhodnogo yazyka
    term.setCursorPos(3, 5)
    term.write("Source language (ru/en/auto): ")
    term.setCursorPos(3, 6)
    local source = read()
    if source == "" then source = "auto" end

    -- Vvod celevogo yazyka
    term.setCursorPos(3, 8)
    term.write("Translate to language... (ru/en): ")
    term.setCursorPos(3, 9)
    local target = read()
    if target == "" then target = "en" end

    -- Otrisovka knopki
    _paintutils.drawFilledBox(10, 11, 27, 13, colors.gray)
    term.setCursorPos(14, 12)
    term.setTextColor(colors.white)
    term.write("Translate!")

    -- Ozhidanie klika myshi
    while true do
        local event, button, x, y = os.pullEvent("mouse_click")
        if button == 1 and x >= 10 and x <= 30 and y >= 11 and y <= 13 then
            break
        end
    end

    function wrapText(text, maxWidth)
        local lines = {}
        local line = ""

        for word in text:gmatch("%S+") do
            if #line + #word + 1 > maxWidth then
                table.insert(lines, line)
                line = word
            else
                if line == "" then
                    line = word
                else
                    line = line .. " " .. word
                end
            end
        end
        if line ~= "" then
            table.insert(lines, line)
        end

        return lines
    end

    -- Vypolnenie perevoda
    term.setBackgroundColor(colors.black)
    term.setCursorPos(3, 17)
    term.write("Translating...")
    local translated = translate(text, source, target)

    term.setBackgroundColor(colors.black)
    term.clear()

    _paintutils.drawFilledBox(1, 17, 50, 19, colors.black)
    term.setCursorPos(2, 2)

    -- Ochistka oblasti i otobrazhenie perevoda
    local maxWidth, _ = term.getSize()
    local wrappedText = wrapText(translated, maxWidth - 4)

    term.setTextColor(colors.green)
    for i, line in ipairs(wrappedText) do
        term.setCursorPos(3, 1 + i)
        if i == 1 then
            term.write("Result: "..line)
        else
            term.write(line)
        end
    end

    -- Ozhidanie vyhoda
    term.setCursorPos(3, 18)
    term.setTextColor(colors.white)
    term.write("Press Enter to translate new text.")
    term.setCursorPos(term.getCursorPos())
    read()
end
