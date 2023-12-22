local utils = require "utils"
local M = {}

local toolchainFolder = "./toolchains/"

-- Need to make this a little more sophisticated than does the folder exist
function M.isInstalled(versions)
    local installed = {}
    for i=1, #versions do
        local file = toolchainFolder .. versions[i]
        -- TODO: figure out possible errs and how to handle
        local exists, err = utils.exists(file)
        -- print("err ".. err)
        installed[versions[i]] = exists
    end
    return installed
end


-- Given the major field of a semantic version, goes thru the list of given
-- semantic versions and collects them all into a table to return
function M.getDeviceOSBranch(versions, major)
    local branchStart = 1
    for i=1, #versions do
        local versionMajor = utils.parseSemanticVersion(versions[i])["major"]
        if versionMajor == major then
            branchStart = i
            break
        end
    end

    local branch = {}
    for i=branchStart, #versions do
        local versionMajor = utils.parseSemanticVersion(versions[i])["major"]
        if versionMajor ~= major then break end
        table.insert(branch, versions[i])
    end

    return branch
end

return M

