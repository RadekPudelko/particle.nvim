local utils = require "utils"

local DeviceOSDirectory = vim.fn.expand("~/.particle/toolchains/deviceOS")

local M = {}

-- TODO: handle any path
-- function M.getAllDeviceOS(DeviceOSDirectory)
function M.getAllDeviceOS()
  local osList = {}

  local handle = vim.loop.fs_scandir(DeviceOSDirectory)
  if not handle then
    print("Failed to scan directory: " .. DeviceOSDirectory)
    return osList
  end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end
    -- TODO: add another check to confirm its a device osList
    if type == "directory" and utils.isSemanticVersion(name) then
      table.insert(osList, name)
    end
  end
  -- TODO: sort by latest

  return osList
end

return M
