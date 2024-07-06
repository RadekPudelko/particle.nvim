local Constants = require("constants")
local Utils = require("utils")

local M = {}

function M.find()
  local path = Utils.findFile(Constants.SettingsFile)
  return path
end

function M.save(config, path)
  local contents = vim.json.encode(config)
  if path == nil then
    path = Constants.SettingsFile
  else
    path = path .. "/" .. Constants.SettingsFile
  end
  print("Save to ", path)
  local file = io.open(path, "w")
  if not file then
    print("Failed to open settings file, err: " .. tostring(file))
    return
  end
  file:write(contents)
  file:close()
end

function M.load(path)
  print("load ", path)
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
    print("Failed to find particle binary")
    return nil
  elseif #result > 1 then
    print("Found multiple particle binaries")
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
function M.getParticleEnv(platforms, settings)
  local env = {}
  env["particle_path"] = getParticle()
  env["buildscript_path"] = Constants.BuildScriptsDirectory .. "/" .. settings["scripts"] .. "/Makefile"
  env["device_os_path"] = Constants.DeviceOSDirectory .. "/" .. settings["device_os"]
  env["appdir"] = Utils.GetParentPath(Utils.findFile(Constants.SettingsFile)) -- TODO: pass this in
  env["platform_id"] = platforms[settings["platform"]]
  env["compiler_path"] = Constants.CompilerDirectory .. "/" .. settings["compiler"] .. "/bin"
  return env
end

-- local function loadProjectJson()
--   local path = Utils.findFile(M.SettingsFile)
--   if not path then
--     return nil, M.SettingsFile .. " not found"
--   end
--
--   local file = io.open(path, "r")
--   if not file then
--     return nil, "Unable to read " .. M.SettingsFile
--   end
--
--   local contents = file:read("*a")
--   file:close()
--   -- TODO: Set up some sort of test or checks here to make sure the file format is as
--   -- we expect it to be
--   local json = vim.json.decode(contents)
--   return json, nil
-- end

-- local function saveProjectJson(settings)
--   local json = vim.json.encode(settings)
--   vim.fn.writefile({json}, M.SettingsFile)
-- end

return M
