local Installed = require("installed")
local utils = require "utils"

local M = {}
M.settingsPath = ".particle.nvim.json"

function M.exists()
  local path = utils.findFile(M.settingsPath)
  return path ~= nil
end

function M.save(config)
    -- config = {deviceOS = "4.2.0", platform = "bsom"}
    local contents = vim.json.encode(config)
    local file = io.open(M.settingsPath, "w")
    if not file then
        print("Failed to open settings file, err: " .. tostring(file))
        return
    end
    file:write(contents)
    file:close()
end

function M.load()
  -- local path = utils.findFile(M.settingsPath)
  -- if not path then
  --   print("Settings not found")
  --   return nil
  -- end
  local contents = utils.readfile(M.settingsPath)
  if not contents then return end
  -- print(contents)
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

-- buildscript - particle makefile path
-- particle - particle cli binary path
-- platform_id
-- device_os_path
-- appdir
function M.getParticleEnv(platforms, settings)
  local env = {}
  env["particle_path"] = getParticle()
  env["buildscript_path"] = Installed.BuildScriptsDirectory .. "/" .. settings["scripts"] .. "/Makefile"
  env["device_os_path"] = Installed.DeviceOSDirectory .. "/" .. settings["device_os"]
  env["appdir"] = utils.GetParentPath(utils.findFile(M.settingsPath)) -- TODO: pass this in
  env["platform_id"] = platforms[settings["platform"]]
  env["compiler_path"] = Installed.CompilerDirectory .. "/" .. settings["compiler"] .. "/bin"
  return env
end

-- local function loadProjectJson()
--   local path = utils.findFile(M.settingsPath)
--   if not path then
--     return nil, M.settingsPath .. " not found"
--   end
--
--   local file = io.open(path, "r")
--   if not file then
--     return nil, "Unable to read " .. M.settingsPath
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
--   vim.fn.writefile({json}, M.settingsPath)
-- end

return M
