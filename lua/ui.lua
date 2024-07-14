local log = require("log")
local Manifest = require("manifest")
local Compile = require("compile")
local settings = require("settings")
local env = require("env")
local Installed = require("installed")

local M = {}

local function format_cur_item(item, want)
  if item == want then
    return "*" .. item
  end
  return item
end

local function CreateMenu(title, lines, on_submit, format_item)
  local opts = {
    prompt = title,
    format_item = format_item,
  }
  vim.ui.select(lines, opts, on_submit)
end

function M.CreateMainMenu()
  local lines = {}
  if not settings.loaded() then
    lines = {"Create config"}
  else
    lines = {
      "Device OS: " .. settings.get_device_os(),
      "Platform: " .. settings.get_platform(),
      "Compiler: " .. settings.get_compiler(),
      "Build Script: " .. settings.get_scripts()
    }
  end

  local on_submit = function(item)
    if item == nil then
      return
    end
    if item == "Create config" then
      -- TODO: settings should try to find a root-like directory for the project to save to
      settings.new()
      settings.save(env.get_app_dir())
      env.setup_env(env.get_app_dir())
      Compile.setup_cc_json_dir()
      M.CreateMainMenu()
    elseif string.find(item, "Device OS:") then
      CreateDeviceOSMenu()
    elseif string.find(item, "Platform:") then
      CreatePlatformMenu()
    elseif string.find(item, "Compiler:") then
      CreateCompilerMenu()
    else
      CreateBuildScriptMenu()
    end
  end

  CreateMenu("Particle.nvim", lines, on_submit)
end

function CreateDeviceOSMenu()
  local cur = settings.get_device_os()
  local lines = Installed.getDeviceOSs()

  local on_submit = function(item)
    if item == nil then
      M.CreateMainMenu()
      return
    end

    settings.set_device_os(item)
    if not Manifest.is_platform_valid_for_device_os(item, settings.get_platform()) then
      CreatePlatformMenu()
    else
      settings.save(env.get_app_dir())
      Compile.setup_cc_json_dir()
      M.CreateMainMenu()
    end
  end

  local format_item = function(item) return format_cur_item(item, cur) end

  CreateMenu("Particle.nvim - Device OS", lines, on_submit, format_item)
end

function CreatePlatformMenu()
  -- Get the valid list of platforms for the current device os
  -- Search manifest["toolchains"] loop platforms where firmware == deviceOS@X.X.X
  -- Convert platforms from numbers to names
  -- Order us giidm vut consider replacing platform names with display neames as used in vscode

  local cur = settings.get_platform()
  local toolchain = Manifest.getToolchain(settings.get_device_os())
  if toolchain == nil then
    log:error(string.format("Failed to find toolchain for device os %s", settings.get_device_os()))
    return
  end

  local lines = {}
  local platformMap = Manifest.getPlatforms()
  for _, platformId in ipairs(toolchain["platforms"]) do
    local platform = platformMap[platformId]
    table.insert(lines, platform)
  end

  local on_submit = function(item)
    if item == nil then
      M.CreateMainMenu()
      return
    end
    settings.set_platform(item)

    settings.save(env.get_app_dir())
    Compile.setup_cc_json_dir()
    M.CreateMainMenu()
  end

  local format_item = function(item) return format_cur_item(item, cur) end

  CreateMenu("Particle.nvim - Platform", lines, on_submit, format_item)
end

function CreateCompilerMenu()
  local cur = settings.get_compiler()
  local lines = Installed.getCompilers()

  local on_submit = function(item)
    if item == nil then
      M.CreateMainMenu()
      return
    end
    settings.set_compiler(item)

    settings.save(env.get_app_dir())
    Compile.setup_cc_json_dir()
    LoadSettings()
    M.CreateMainMenu()
  end

  local format_item = function(item) return format_cur_item(item, cur) end

  CreateMenu("Particle.nvim - Compiler", lines, on_submit, format_item)
end

function CreateBuildScriptMenu()
  local cur = settings.get_scripts()
  local lines = Installed.getBuildScripts()

  local on_submit = function(item)
    if item == nil then
      M.CreateMainMenu()
      return
    end
    settings.set_scripts(item)

    settings.save(env.get_app_dir())
    M.CreateMainMenu()
  end

  local format_item = function(item) return format_cur_item(item, cur) end

  CreateMenu("Particle.nvim - Build Script", lines, on_submit, format_item)
end

return M
