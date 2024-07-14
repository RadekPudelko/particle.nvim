local config = require("config")
local log = require("log")
local Utils = require("utils")
local Manifest = require("manifest")
local Compile = require("compile")
local settings = require("settings")
local env = require("env")
local Installed = require("installed")
local Constants = require("constants")
local Commands = require("overseer_commands")

--TODO after create config, overseer commands should be registered

local project_root = nil

local initialized = 0
local settings_loaded = false

local M = {}
-- TODO: add way to show user log file location
-- TODO: add way to quickly open log file, like LspLog command

M.PROJECT_DEVICE_OS = 1
M.PROJECT_LOCAL= 2

function M.hello()
  return "hello"
end

function M.get_device_os_ccjson_dir()
  if settings == nil then
    return nil
  end
  local cc_dir = Compile.get_cc_json_dir()
  if not vim.fn.isdirectory(cc_dir) then
    return nil
  end
  return cc_dir
end

-- TODO: check if it exists?
function M.get_query_driver()
  if settings == nil then
    return nil
  end
  return settings.get_query_driver()
end

-- TODO: stop searching early if .git found?
-- TODO: unit test this
function M.get_project_type(path)
  local match = string.match(path, "deviceOS/%d+%.%d+%.%d+")
  if match ~= nil then
    -- TODO fix this trash
    local root = vim.fn.fnamemodify(path, ":h")
    local goodRoot = root
    while true do
      match = string.match(root, "deviceOS/%d+%.%d+%.%d+")
      if match ~= nil then
        goodRoot = root
        root = vim.fn.fnamemodify(root, ":h")
      else
        return M.PROJECT_DEVICE_OS, goodRoot
      end
    end
  end

  local results = vim.fs.find({Constants.SettingsFile, type = "file", upward=true})
  if #results == 0 then
    results = vim.fs.find({Constants.PropertiesFile, type = "file", upward=true})
  end

  if #results ~= 0 then
    -- Get dir of project root file
    local root = vim.fs.dirname(results[1])
    return M.PROJECT_LOCAL, root
  end

  return nil, nil
end

-- Project root for saving settings file to
function M.find_project_root()
  local _, root = M.get_project_type(vim.fn.getcwd())
  if root ~= nil then
    return root
  end
  root = vim.fs.root(0, {'.git'})
  if root ~= nil then
    return root
  end
  return vim.fn.getcwd()
end

function M.get_settings()
  return settings
end

--TODO: Switching platform should try to do something to fix the compile_commands.json that is
--used by the device os. This can be done by checking if there exists a compile_commands json
--for the specific platform for the device os and relinking it so that it is active. Otherwise, it
--can prompt the user if it would like to compile the device os to create the compile commands.
-- Would also have to prompt on change in devie os. IDK about change in compiler? Could use custom
-- link names in the modules fokder than link in to the device os.
-- This can get messy with multiple projects using hte same device os but different platforms.
-- Maybe could merge the compile commands json file from device os and project
-- Or could have particle.nvim supplu the correct compile commands json as the query driver arg
-- to clangd!!
--TODO: Need to keep track of which compile-comamnds are linked if going with a linked approach, but
--not for a clangd supplied file via --compile-commands-dir=
-- TODO: add a menu for additional CCFLAGs
-- TODO: add way of determining whether compile-os with bear finished so that it can be restarted on boot
-- TODO: A Clean os is not required for all platforms, only for those for which there is a shared command.
-- Its possible to tell which have the same command via platform-ids.mk in deviceOs/build, but that doesn't
-- necessarily tell you if you need to clean
-- Could look at build/target folder?

-- TODO: Could restart LSP after compiling, technically it works fine, but the diagnostics aren't resolved until
-- restart

-- TODO: Take options for window
-- Configuration
-- Auto compile device os
-- logging
--

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

function CreateMainMenu()
  local lines = {}
  if not settings_loaded then
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
      settings.save(project_root)
      LoadSettings()
      CreateMainMenu()
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
      CreateMainMenu()
      return
    end

    settings.set_device_os(item)
    if not Manifest.is_platform_valid_for_device_os(item, settings.get_platform()) then
      CreatePlatformMenu()
    else
      settings.save(project_root)
      LoadSettings()
      CreateMainMenu()
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
      CreateMainMenu()
      return
    end
    settings.set_platform(item)
    settings.save(project_root)
    LoadSettings()
    CreateMainMenu()
  end

  local format_item = function(item) return format_cur_item(item, cur) end

  CreateMenu("Particle.nvim - Platform", lines, on_submit, format_item)
end

function CreateCompilerMenu()
  local cur = settings.get_compiler()
  local lines = Installed.getCompilers()

  local on_submit = function(item)
    if item == nil then
      CreateMainMenu()
      return
    end
    settings.set_compiler(item)
    settings.save(project_root)
    LoadSettings()
    CreateMainMenu()
  end

  local format_item = function(item) return format_cur_item(item, cur) end

  CreateMenu("Particle.nvim - Compiler", lines, on_submit, format_item)
end

function CreateBuildScriptMenu()
  local cur = settings.get_scripts()
  local lines = Installed.getBuildScripts()

  local on_submit = function(item)
    if item == nil then
      CreateMainMenu()
      return
    end
    settings.set_scripts(item)
    settings.save(project_root)
    LoadSettings()
    CreateMainMenu()
  end

  local format_item = function(item) return format_cur_item(item, cur) end

  CreateMenu("Particle.nvim - Build Script", lines, on_submit, format_item)
end

function LoadSettings()

  settings_loaded = false
  local settings_path = settings.find()
  if settings_path == nil then
    log:info("No settings file found in ", vim.fn.getcwd())
    return nil
  end

  log:info("Loading settings from %s", settings_path)
  -- TODO: Validate all settings json fields are present/valid
  local err = settings.load(settings_path)
  if err ~= nil then
    log:info("Error in loading settings from %s, err=%s", settings_path, err)
    return
  end
  Compile.setup_cc_json_dir()

  local platformMap = Manifest.getPlatforms()
  env.setup_env(platformMap, vim.fs.dirname(settings_path))
  settings_loaded = true
  return settings_path
end

local function setMappings()
  vim.api.nvim_create_user_command('Particle', function()
    vim.cmd('lua require("particle").project()')
  end, {
      desc = 'Opens the Particle project menu',
    })
  vim.keymap.set("n", "<leader><leader>p", ":lua require'particle'.project()<cr>", { nowait=false, noremap=true, silent=true, desc = "Launch Particle.nvim local project configuration" })
end

function M.setup(user_config)
  if initialized == 0 then
    initialized = 1
    config.setup(user_config)
    setMappings()
    Utils.ensure_directory(Constants.DataDir)
    Utils.ensure_directory(Constants.OSCCJsonDir)
    Utils.ensure_directory(Constants.ManifestDir)
    Utils.ensure_directory(Constants.WorkbenchExtractDir)

    local err = Manifest.setup()
    if err ~= nil then
      log:error("Failed to load manifest, err=%s", err)
    end

    project_root = LoadSettings()
    if project_root ~= nil then
      project_root = vim.fs.dirname(project_root)
    else
      project_root = M.find_project_root()
    end
    log:info("Project root ", project_root)
    if settings == nil then
      return
    end

    Commands.setup()
    -- local a = 1
    -- while a ~= 5000000000 do
    --   a = a + 1
    -- end
    --   -- Your startup code here
    --   print("Plugin startup complete.")
    -- end, 10000)  -- 5 seconds delay

    initialized = 2
    print("init complete")
  end
end

function M.project()
  M.setup()
  CreateMainMenu()
end

log:info("Hello from particle.nvim")

return M
