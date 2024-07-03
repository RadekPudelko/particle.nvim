local Installed = require("installed")
local Compile = require("compile")

local M = {}

local function create_make_command(make_target, settings, env)
  local parts = {}
  table.insert(parts, "make -f " .. env["buildscript_path"] .. " -s " .. make_target)
  table.insert(parts, "PARTICLE_CLI_PATH=" .. env["particle_path"])
  table.insert(parts, "DEVICE_OS_PATH=" .. env["device_os_path"])
  table.insert(parts, "APPDIR=" .. env["appdir"])
  table.insert(parts, "PLATFORM=" .. settings["platform"])
  table.insert(parts, "PLATFORM_ID=" .. env["platform_id"])
  return table.concat(parts, " ")
end

local function create_bear_command(make_target, settings, env)
  return "bear -- " .. create_make_command(make_target, settings, env)
end

local function create_bear_append_command(make_target, settings, env)
  return "bear --append -- " .. create_make_command(make_target, settings, env)
end

function M.compile_user(settings, env)
  return create_bear_append_command("compile-user", settings, env)
end
function M.flash_user(settings, env)
  return create_make_command("flash-user", settings, env)
end
function M.clean_user(settings, env)
  local parts = {}
  table.insert(parts, "rm -f compile_commands.json")
  table.insert(parts, "&&")
  table.insert(parts, create_make_command("clean-user", settings, env))
  return table.concat(parts, " ")
end

function M.compile_os(settings, env, cc_json_path)
  local parts = {}
  table.insert(parts, "cd " .. Installed.DeviceOSDirectory .. "/" .. settings["device_os"])
  table.insert(parts, "&&")
  table.insert(parts, "bear --append --output " .. cc_json_path .. " --")
  table.insert(parts, "make -s all")
  table.insert(parts, "PLATFORM=" .. settings["platform"])
  table.insert(parts, "PLATFORM_ID=" .. env["platform_id"])
  return table.concat(parts, " ")
end

-- Assumes the ccjson dir already exists
function M.compile_all(settings, env)
  local parts = {}
  table.insert(parts, M.compile_os(settings, env, Compile.get_cc_json(settings)))
  table.insert(parts, "&&")
  table.insert(parts, M.compile_user(settings, env))
  return table.concat(parts, " ")
end

function M.flash_all(settings, env)
  return create_make_command("flash-all", settings, env)
end

function M.clean_all(settings, env)
  local parts = {}
  table.insert(parts, "rm -f " .. Compile.get_cc_json(settings))
  table.insert(parts, "&&")
  table.insert(parts, create_make_command("clean-all", settings, env))
  return table.concat(parts, " ")
end

-- function M.compile_debug(settings, env)
--   return create_bear_append_command("compile_debug", settings, env)
-- end
-- function M.flash_debug(settings, env)
--   return create_make_command("flash_debug", settings, env)
-- end
-- function M.clean_debug(settings, env)
--   return create_make_command("clean_debug", settings, env)
-- end

return M
