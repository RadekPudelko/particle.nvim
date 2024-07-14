local Constants = require("constants")
local settings = require("settings")
local log = require("log")

local M = {}

local env = {}

-- TODO: find particle binary using lua
local function get_particle_binary()
  local result = vim.api.nvim_call_function('systemlist', {
    "which particle"
  })
  if #result == 0 then
    log:warn("Failed to find particle binary")
    return nil
  end
  return result[1]
end

-- buildscript - particle makefile path
-- particle - particle cli binary path
-- device_os_path
-- appdir
function M.setup_env(root)
  env = {}
  env.particle_path = get_particle_binary()
  env.appdir = root
end

function M.get_particle_path()
  return env.particle_path
end

function M.get_app_dir()
  return env.appdir
end

function M.get_buildscript_path()
  return Constants.BuildScriptsDirectory .. "/" .. settings.get_scripts() .. "/Makefile"
end

function M.get_device_os_path()
  return Constants.DeviceOSDirectory .. "/" .. settings.get_device_os()
end

function M.get_compiler_path()
  return Constants.CompilerDirectory .. "/" .. settings.get_compiler() .. "/bin"
end

function M.get_env()
  return env
end

return M
