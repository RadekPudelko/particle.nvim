local utils = require "utils"

local M = {}

local settingsPath = ".partice.nvim.json"

function M.save(config)
    -- config = {deviceOS = "4.2.0", platform = "bsom"}
    local contents = vim.json.encode(config)
    local file = io.open(settingsPath, "w")
    if not file then
        print("Failed to open settings file, err: " .. tostring(file))
        return
    end
    file:write(contents)
    file:close()
end

function M.load()
    local contents = utils.readfile(settingsPath)
    if not contents then return end
    -- print(contents)
    return vim.json.decode(contents)
end

return M

-- lua require("settings").save()
