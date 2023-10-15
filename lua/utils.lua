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

return M

