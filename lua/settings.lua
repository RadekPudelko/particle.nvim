local Constants = require("constants")
local Utils = require("utils")
local log = require("log")

local M = {}

local settings = {}
local settings_loaded = false

-- TODO: these defaults need to be generated according to whats installed locally or blank
function M.new()
  settings = {
    ["device_os"] = "6.1.0",
    ["platform"] = "bsom",
    ["compiler"] = "10.2.1",
    ["scripts"] = "1.15.0"
  }
  settings_loaded = true
end

function M.find()
  local results = vim.fs.find({Constants.SettingsFile, type = "file", upward=true})
  if #results == 0 then
    return nil
  end

  return results[1]
end

-- path is the folder to save into
function M.save(path)
  -- TODO: check is empty?
  local contents = vim.json.encode(settings)
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

-- TODO: validate
function M.load(path)
  local err, contents = Utils.read_file(path)
  if err ~= nil then
    return err
  end
  if not contents then
    return string.format("File is empty")
  end

  local decoded = vim.json.decode(contents)
  settings = {}
  settings.device_os = decoded.device_os
  settings.platform = decoded.platform
  settings.compiler = decoded.compiler
  settings.scripts = decoded.scripts
  settings_loaded = true
  return nil
end

function M.get_query_driver()
  return Constants.CompilerDirectory .. "/" .. settings["compiler"] .. "/bin/arm-none-eabi-gcc"
end

function M.set_device_os(device_os)
  settings.device_os = device_os
end
function M.set_platform(platform)
  settings.platform = platform
end
function M.set_compiler(compiler)
  settings.compiler = compiler
end
function M.set_scripts(scripts)
  settings.scripts = scripts
end

function M.get_device_os()
  return settings.device_os
end
function M.get_platform()
  return settings.platform
end
function M.get_compiler()
  return settings.compiler
end
function M.get_scripts()
  return settings.scripts
end

function M.loaded()
  return settings_loaded
end

return M
