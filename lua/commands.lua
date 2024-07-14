local Constants = require("constants")
-- local Installed = require("installed")
local Compile = require("compile")
local settings = require("settings")
local env = require("env")

local M = {}

local function create_make_command(make_target)
  local parts = {}
  table.insert(parts, "make -f " .. env.get_buildscript_path() .. " -s " .. make_target)
  table.insert(parts, "PARTICLE_CLI_PATH=" .. env.get_particle_path())
  table.insert(parts, "DEVICE_OS_PATH=" .. env.get_device_os_path())
  table.insert(parts, "APPDIR=" .. env.get_app_dir())
  table.insert(parts, "PLATFORM=" .. settings.get_platform())
  table.insert(parts, "PLATFORM_ID=" .. env.get_platform_id())
  return table.concat(parts, " ")
end

local function create_bear_append_command(make_target)
  return "bear --append -- " .. create_make_command(make_target)
end

function M.compile_user()
  return create_bear_append_command("compile-user")
end
function M.flash_user()
  return create_bear_append_command("flash-user")
end
function M.clean_user()
  local parts = {}
  table.insert(parts, "rm -f compile_commands.json")
  table.insert(parts, "&&")
  table.insert(parts, create_make_command("clean-user"))
  return table.concat(parts, " ")
end

-- TODO make -f instead of cd
function M.compile_os()
  local parts = {}
  table.insert(parts, "cd " .. Constants.DeviceOSDirectory .. "/" .. settings.get_device_os() .. "/modules")
  table.insert(parts, "&&")
  table.insert(parts, "bear --append --output " .. Compile.get_cc_json() .. " --")
  table.insert(parts, "make -s all")
  table.insert(parts, "PLATFORM=" .. settings.get_platform())
  table.insert(parts, "PLATFORM_ID=" .. env.get_platform_id())
  return table.concat(parts, " ")
end

-- Assumes the ccjson dir already exists
-- compile-all from buildscript not used here as it bear needs to be invoked for the os and user compilation seperatly
function M.compile_all()
  local parts = {}
  table.insert(parts, M.compile_os())
  table.insert(parts, "&&")
  table.insert(parts, "cd " .. env.get_app_dir())
  table.insert(parts, "&&")
  table.insert(parts, M.compile_user())
  return table.concat(parts, " ")
end

-- TODO: IDK if I like this
function M.flash_all()
  local parts = {}
  table.insert(parts, M.compile_all())
  table.insert(parts, "&&")
  table.insert(parts, create_make_command("flash-all"))
  return table.concat(parts, " ")
end

function M.clean_os()
  local parts = {}
  table.insert(parts, "rm -f " .. Compile.get_cc_json())
  table.insert(parts, "&&")
  table.insert(parts, "cd " .. Constants.DeviceOSDirectory .. "/" .. settings.get_device_os() .. "/modules")
  table.insert(parts, "&&")
  table.insert(parts, "make -s clean")
  table.insert(parts, "PLATFORM=" .. settings.get_platform())
  table.insert(parts, "PLATFORM_ID=" .. env.get_platform_id())
  return table.concat(parts, " ")
end

function M.clean_all()
  local parts = {}
  table.insert(parts, "rm -f compile_commands.json")
  table.insert(parts, "&&")
  table.insert(parts, "rm -f " .. Compile.get_cc_json())
  table.insert(parts, "&&")
  table.insert(parts, create_make_command("clean-all"))
  return table.concat(parts, " ")
end

-- function M.compile_debug()
--   return create_bear_append_command("compile_debug")
-- end
-- function M.flash_debug()
--   return create_make_command("flash_debug")
-- end
-- function M.clean_debug()
--   return create_make_command("clean_debug")
-- end

return M
