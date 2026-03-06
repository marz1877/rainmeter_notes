

local fileList = {}
local currentIndex = 1
local notesPath = ""
local currentFilePath = ""
local initialized = false

function Initialize()
    -- Initialize on first Update cycle
end

function Update()
    if not initialized then
        initialized = true
        InitializeLogic()
        return "Done"
    end
end

function LogToFile(msg)
    local path = SKIN:GetVariable('CURRENTPATH') .. 'notes_debug.txt'
    local f = io.open(path, 'a')
    if f then
        f:write(os.date('%Y-%m-%d %H:%M:%S') .. ' - ' .. tostring(msg) .. '\n')
        f:close()
    end
end

function InitializeLogic()
    local status, err = pcall(function()
        local rawPath = SKIN:GetVariable('NotesPath', '')
        LogToFile("Initializing logic. Raw path: [" .. tostring(rawPath) .. "]")
        
        notesPath = rawPath:gsub('"', '')
        if notesPath ~= "" and notesPath:sub(-1) ~= "\\" then
            notesPath = notesPath .. "\\"
        end

        LogToFile("Sanitized path: [" .. notesPath .. "]")
        
        -- Trigger the RunCommand measure to list files
        SKIN:Bang('!CommandMeasure', 'MeasureFileList', 'Run')
    end)
    
    if not status then
        LogToFile("CRITICAL LUA ERROR: " .. tostring(err))
        SafeBang('!SetOption', 'MeterNoteText', 'Text', 'LUA ERROR: ' .. tostring(err))
        SafeBang('!UpdateMeter', 'MeterNoteText')
        SafeBang('!Redraw')
    end
end

-- Called from Rainmeter after MeasureFileList finishes
function ParseFileListFromMeasure()
    local output = SKIN:GetMeasure('MeasureFileList'):GetStringValue()
    LogToFile("Raw output from PS measure: [" .. tostring(output) .. "]")
    
    fileList = {}
    for line in output:gmatch("[^\r\n]+") do
        if line and line:match('%S') then
            -- PS FullName gives absolute paths
            table.insert(fileList, line)
        end
    end
    
    LogToFile("Parsed " .. #fileList .. " absolute paths from measure.")
    
    if #fileList > 0 then
        if currentIndex > #fileList then currentIndex = 1 end
        UpdateRainmeter()
    else
        LogToFile("No files found after parsing.")
        SafeBang('!SetOption', 'MeterTitle', 'Text', 'Notes Viewer (No Files)')
        SafeBang('!SetOption', 'MeterNoteText', 'Text', 'No .txt files found in: ' .. notesPath)
        SafeBang('!UpdateMeter', '*')
        SafeBang('!Redraw')
    end
end

function UpdateRainmeter()
    if #fileList == 0 then return end
    
    currentFilePath = fileList[currentIndex]
    
    -- Extract filename for the title
    local filename = currentFilePath:match("([^\\]+)$") or currentFilePath
    LogToFile("Reading file: " .. currentFilePath)
    
    local f = io.open(currentFilePath, "r")
    local content = ""
    if f then
        content = f:read("*all")
        f:close()
    else
        LogToFile("Failed to open file for reading.")
        content = "Error: Could not read file [*#CRLF#]" .. currentFilePath .. "[*]"
    end
    
    -- Escape for Rainmeter
    content = content:gsub('\r\n', '#CRLF#')
    content = content:gsub('\n', '#CRLF#')
    content = content:gsub('%[', '[*')
    content = content:gsub('%]', '*]')
    
    local titleText = filename .. "  (" .. currentIndex .. " / " .. #fileList .. ")"
    titleText = titleText:gsub('%[', '[*')
    titleText = titleText:gsub('%]', '*]')

    SafeBang('!SetOption', 'MeterTitle', 'Text', titleText)
    SafeBang('!SetOption', 'MeterNoteText', 'Text', content)
    SafeBang('!SetVariable', 'CurrentFile', currentFilePath)
    
    SafeBang('!UpdateMeter', '*')
    SafeBang('!Redraw')
end

function SafeBang(bangName, ...)
    local params = {...}
    local cmd = bangName
    for _, p in ipairs(params) do
        local s = tostring(p):gsub('"', '""')
        cmd = cmd .. ' "' .. s .. '"'
    end
    SKIN:Bang(cmd)
end

function Next()
    if #fileList == 0 then return end
    currentIndex = currentIndex + 1
    if currentIndex > #fileList then currentIndex = 1 end
    UpdateRainmeter()
end

function Previous()
    if #fileList == 0 then return end
    currentIndex = currentIndex - 1
    if currentIndex < 1 then currentIndex = #fileList end
    UpdateRainmeter()
end

function OpenInNotepad()
    if currentFilePath ~= "" then
        LogToFile("Opening in notepad: " .. currentFilePath)
        SKIN:Bang('["' .. currentFilePath .. '"]')
    end
end

