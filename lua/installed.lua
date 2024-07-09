local Utils = require("utils")
local Constants = require("constants")

local M = {}

-- TODO: handle any path
-- function M.getAllDeviceOS(DeviceOSDirectory)
function M.getDeviceOSs()
  local isDeviceOS = function(name, type)
    if type == "directory" and Utils.isSemanticVersion(name) then
      return true
    end
    return false
  end

  local list = Utils.scanDirectory(Constants.DeviceOSDirectory, isDeviceOS)
  -- TODO: sort by latest

  return list
end

function M.getCompilers()
  -- TODO: improve this check
  local isCompiler = function(name, type)
    if type == "directory" and Utils.isSemanticVersion(name) then
      return true
    end
    return false
  end

  local list = Utils.scanDirectory(Constants.CompilerDirectory, isCompiler)
  -- TODO: sort by latest

  return list
end

function M.getBuildScripts()
  -- TODO: improve this check
  local isCompiler = function(name, type)
    if type == "directory" and Utils.isSemanticVersion(name) then
      return true
    end
    return false
  end

  local list = Utils.scanDirectory(Constants.BuildScriptsDirectory, isCompiler)
  -- TODO: sort by latest

  return list
end

return M
