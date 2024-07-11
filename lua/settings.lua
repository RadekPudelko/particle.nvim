local Constants = require("constants")
local Utils = require("utils")
local log = require("log")

local M = {}

function M.find()
  local results = vim.fs.find({Constants.SettingsFile, type = "file", upward=true})

  if #results == 0 then
    return nil
  end

  return results[1]
end

function M.save(config, path)
  local contents = vim.json.encode(config)
  if path == nil then
    path = Constants.SettingsFile
  else
    path = path .. "/" .. Constants.SettingsFile
  end
  local file, err = io.open(path, "w")
  if not file then
    log:error("Failed to save settings to path=%s, err=%s", path, err)
    return
  end
  file:write(contents)
  file:close()
end

-- TODO: return the error!
function M.load(path)
  local contents = Utils.read_file(path)
  if not contents then return end
  return vim.json.decode(contents)
end

-- TODO: find particle binary using lua
local function getParticle()
  local result = vim.api.nvim_call_function('systemlist', {
    "which particle"
  })
  if #result == 0 then
    log:warn("Failed to find particle binary")
    return nil
  end
  return result[1]
end

-- TODO: these defaults need to be generated according to whats installed locally or blank
function M.default()
  local settings = {
    ["device_os"] = "6.1.0",
    ["platform"] = "bsom",
    ["compiler"] = "10.2.1",
    ["scripts"] = "1.15.0"
  }
  return settings
end

function M.get_query_driver(settings)
  return Constants.CompilerDirectory .. "/" .. settings["compiler"] .. "/bin/arm-none-eabi-gcc"
end

-- buildscript - particle makefile path
-- particle - particle cli binary path
-- platform_id
-- device_os_path
-- appdir
function M.getParticleEnv(platforms, settings, root)
  local env = {}
  env["particle_path"] = getParticle()
  env["buildscript_path"] = Constants.BuildScriptsDirectory .. "/" .. settings["scripts"] .. "/Makefile"
  env["device_os_path"] = Constants.DeviceOSDirectory .. "/" .. settings["device_os"]
  env["appdir"] = root
  env["platform_id"] = platforms[settings["platform"]]
  env["compiler_path"] = Constants.CompilerDirectory .. "/" .. settings["compiler"] .. "/bin"
  return env
end

return M
