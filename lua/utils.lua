local M = {}

function M.printTable(t)
    local printTable_cache = {}

    local function sub_printTable(t, indent)
        if(printTable_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            printTable_cache[tostring(t)] = true
            if(type(t) == "table") then
                for pos,val in pairs(t) do
                    if(type(val) == "table") then
                        print(indent .. "[" .. pos .. "] => " .. tostring(t).. " {")
                        sub_printTable(val, indent .. string.rep( " ", string.len(pos)+8))
                        print(indent .. string.rep( " ", string.len(pos)+6 ) .. "}")
                    elseif(type(val) == "string") then
                        print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end

    if(type(t) == "table" ) then
        print(tostring(t) .. " {")
        sub_printTable(t, "  ")
        print("}")
    else
        sub_printTable(t, "  ")
    end
end

-- Reads the entire file
function M.readfile(path)
    local file = io.open(path, "r")
    if not file then return end

    local txt = file:read("*a")
    file:close()
    return txt
end

-- True if a file or folder exists at path
function M.exists(path)
    local ok, err, code = os.rename(path, path)
    if not ok then
        if code == 13 then
            -- Permission denied, but directory exists
            return true
        end
        return false, err
    end
    return true
end

function M.isSemanticVersion(version)
    if #version == 0 then return false end
    if not string.match(version, "%d+%.%d+%.%d+") then
        return false
    end
    return true
end

-- synchronous shell command executation using vim.system()
function M.run(command)
    local obj = vim.system(command, {text = true}):wait()
    if obj.code ~= 0 then
        local cmd = table.concat(command, " ")
        print("error in command: " .. cmd)
        print("code " .. obj.code)
        print("stdout " .. obj.stdout)
        print("stderr " .. obj.stderr)
        return false
    end
    return true
end

return M

