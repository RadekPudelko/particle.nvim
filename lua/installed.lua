local utils = require("utils")

local M = {}
M.DeviceOSDirectory = vim.fn.expand("~/.particle/toolchains/deviceOS")
M.CompilerDirectory = vim.fn.expand("~/.particle/toolchains/gcc-arm")
M.BuildScriptsDirectory = vim.fn.expand("~/.particle/toolchains/buildscripts")

-- TODO: handle any path
-- function M.getAllDeviceOS(DeviceOSDirectory)
function M.getDeviceOSs()
  local isDeviceOS = function(name, type)
    if type == "directory" and utils.isSemanticVersion(name) then
      return true
    end
    return false
  end

  local list = utils.scanDirectory(M.DeviceOSDirectory, isDeviceOS)
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

  local list = utils.scanDirectory(M.CompilerDirectory, isCompiler)
  -- TODO: sort by latest

  return list
end

function M.getBuildScripts()
  -- TODO: improve this check
  local isCompiler = function(name, type)
    if type == "directory" and utils.isSemanticVersion(name) then
      return true
    end
    return false
  end

  local list = utils.scanDirectory(M.BuildScriptsDirectory, isCompiler)
  -- TODO: sort by latest

  return list
end

return M
