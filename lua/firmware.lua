local api = vim.api
local utils = require "utils"

local M = {}

local deviceOSChangelogPath

function M.getDeviceOSChanges(version)
    local changelog = utils.readfile(deviceOSChangelogPath)

    -- Versions with hypthens need to have %- to find
    local pattern = "## " .. string.gsub(version, "-", "%%-")
    local versionStart, versionEnd = string.find(changelog, pattern)
    local nextVersionStart, _ = string.find(string.sub(changelog, versionEnd), "## %d+%.%d+%.%d+")
    return string.sub(changelog, versionStart, versionStart + nextVersionStart)
end

function M.setup(path)
    deviceOSChangelogPath = path .. "CHANGELOG.md"

    -- Want to replace these api calls with something that will give me an error
    local cmd = "curl -Ls https://raw.githubusercontent.com/particle-iot/device-os/develop/CHANGELOG.md -o " .. deviceOSChangelogPath
    -- TODO: How do I get an error message out of these?
    -- This fails if the deviceOSChangelogPath doesn't exist
    local result = api.nvim_call_function('system', {
        cmd
    })

    if not utils.exists(deviceOSChangelogPath) then
        print(cmd)
        print("Failed to download Changlog")
    end

end

return M

