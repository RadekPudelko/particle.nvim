local utils = require("utils")

local DeviceOSDirectory = vim.fn.expand("~/.particle/toolchains/deviceOS")
local CompilerDirectory = vim.fn.expand("~/.particle/toolchains/gcc-arm")

local M = {}

-- TODO: handle any path
-- function M.getAllDeviceOS(DeviceOSDirectory)
function M.getAllDeviceOS()
  local isDeviceOS = function(name, type)
    if type == "directory" and utils.isSemanticVersion(name) then
      return true
    end
    return false
  end

  local list = utils.scanDirectory(DeviceOSDirectory, isDeviceOS)
  -- TODO: sort by latest

  return list
end

function M.getCompilers()
  -- TODO: improve this check
  local isCompiler = function(name, type)
    if type == "directory" and utils.isSemanticVersion(name) then
      return true
    end
    return false
  end

  local list = utils.scanDirectory(CompilerDirectory, isCompiler)
  -- TODO: sort by latest

  return list
end

return M
