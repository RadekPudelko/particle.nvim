local Menu = require("nui.menu")
local Utils = require("utils")
local Manifest = require("manifest")
local Compile = require("compile")
local Settings = require("settings")
local Installed = require("installed")
local Constants = require("constants")
local Commands = require("overseer_commands")

local settings = nil
local env = nil
local manifest = nil

local project_root = nil

local M = {}

M.PROJECT_DEVICE_OS = 1
M.PROJECT_LOCAL= 2

function M.hello()
  return "hello"
end

function M.get_device_os_ccjson_dir()
  if settings == nil then
    return nil
  end
  local cc_dir = Compile.get_cc_json_dir(settings)
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
  return Settings.get_query_driver(settings)
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

  local root = Utils.findFile(Constants.SettingsFile)
  if root == nil then
    root = Utils.findFile(Constants.PropertiesFile)
  end
  if root ~= nil then
    -- Get dir of project root file
    root = vim.fn.fnamemodify(root, ":h")
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

local function CreateMenu(title, lines, on_close, on_submit)
  local items = {}
  for _, item in ipairs(lines) do
    table.insert(items, Menu.item(item))
  end

  local menu = Menu({
    position = "50%",
    size = {
      width = 40,
      height = 10,
    },
    border = {
      style = "single",
      text = {
        top = title,
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  }, {
      lines = items,
      max_width = 20,
      keymap = {
        focus_next = { "j", "<Down>", "<Tab>" },
        focus_prev = { "k", "<Up>", "<S-Tab>" },
        close = { "q", "<Esc>", "<C-c>" },
        submit = { "<CR>", "<Space>" },
      },
      on_close = on_close,
      on_submit = on_submit,
    })
  menu:mount()
end

function CreateMainMenu(manifest)
  local lines = {}
  if settings == nil then
    lines = {Menu.item("Create config")}
  else
    lines = {
      Menu.item("Device OS: " .. settings["device_os"]),
      Menu.item("Platform: " .. settings["platform"]),
      Menu.item("Compiler: " .. settings["compiler"]),
      Menu.item("Build Script: " .. settings["scripts"])
    }
  end

  local on_close = function() end

  local on_submit = function(item)
    if item.text == "Create config" then
      -- TODO: settings should try to find a root-like directory for the project to save to
      Settings.save(Settings.default(), project_root)
      LoadSettings(manifest)
      CreateMainMenu(manifest)
    elseif string.find(item.text, "Device OS:") then
      CreateDeviceOSMenu(manifest)
    elseif string.find(item.text, "Platform:") then
      CreatePlatformMenu(manifest)
    elseif string.find(item.text, "Compiler:") then
      CreateCompilerMenu(manifest)
    else
      CreateBuildScriptMenu(manifest)
    end
  end

  CreateMenu("Particle.nvim", lines, on_close, on_submit)
end

function CreateDeviceOSMenu(manifest)
  local cur = settings["device_os"]
  local lines = {}
  local versions = Installed.getDeviceOSs()
  for _, version in ipairs(versions) do
    if version == cur then
      version = "*" .. version
    end
    table.insert(lines, Menu.item(version))
  end

  local on_close = function() CreateMainMenu(manifest) end

  local on_submit = function(item)
    local sel = item.text
    sel = string.gsub(sel, "*", "")
    settings["device_os"] = sel
    if not Manifest.is_platform_valid_for_device_os(manifest, sel, settings["platform"]) then
      CreatePlatformMenu(manifest)
    else
      Settings.save(settings)
      LoadSettings(manifest)
      CreateMainMenu(manifest)
    end
  end

  CreateMenu("Particle.nvim - Device OS", lines, on_close, on_submit)
end

function CreatePlatformMenu(manifest)
  -- Get the valid list of platforms for the current device os
  -- Search manifest["toolchains"] loop platforms where firmware == deviceOS@X.X.X
  -- Convert platforms from numbers to names
  -- Order us giidm vut consider replacing platform names with display neames as used in vscode

  local cur = settings["platform"]
  local toolchain = Manifest.getToolchain(manifest, settings["device_os"])
  if toolchain == nil then
    print("Failed to find toolchain info for device os " .. settings["device_os"])
    return
  end

  local lines = {}
  local platformMap = Manifest.getPlatforms(manifest)
  for _, platformId in ipairs(toolchain["platforms"]) do
    local platform = platformMap[platformId]
    if platform == cur then
      platform = "*" .. platform
    end
    table.insert(lines, Menu.item(platform))
  end

  local on_close = function() CreateMainMenu(manifest) end

  local on_submit = function(item)
    local sel = item.text
    sel = string.gsub(sel, "*", "")
    settings["platform"] = sel
    Settings.save(settings)
    LoadSettings(manifest)
    CreateMainMenu(manifest)
  end

  CreateMenu("Particle.nvim - Platform", lines, on_close, on_submit)
end

function CreateCompilerMenu(manifest)
  local cur = settings["compiler"]
  local lines = {}
  local versions = Installed.getCompilers()
  for _, version in ipairs(versions) do
    if version == cur then
      version = "*" .. version
    end
    table.insert(lines, Menu.item(version))
  end

  local on_close = function() CreateMainMenu(manifest) end

  local on_submit = function(item)
    local sel = item.text
    sel = string.gsub(sel, "*", "")
    settings["compiler"] = sel
    Settings.save(settings)
    LoadSettings(manifest)
    CreateMainMenu(manifest)
  end

  CreateMenu("Particle.nvim - Compiler", lines, on_close, on_submit)
end

function CreateBuildScriptMenu(manifest)
  local cur = settings["scripts"]
  local lines = {}
  local versions = Installed.getBuildScripts()
  for _, version in ipairs(versions) do
    if version == cur then
      version = "*" .. version
    end
    table.insert(lines, Menu.item(version))
  end

  local on_close = function() CreateMainMenu(manifest) end

  local on_submit = function(item)
    local sel = item.text
    sel = string.gsub(sel, "*", "")
    settings["scripts"] = sel
    Settings.save(settings)
    LoadSettings(manifest)
    CreateMainMenu(manifest)
  end

  CreateMenu("Particle.nvim - Build Script", lines, on_close, on_submit)
end

function LoadSettings(manifest)
  print("load settings")
  settings = nil
  local settings_path = Settings.find()
  print("settings path ", settings_path)
  if settings_path ~= nil then
    -- TODO: Validate all settings json fields are present/valid
    settings = Settings.load(settings_path)
    Compile.setup_cc_json_dir(settings)

    if settings == nil then
      print("Failed to load settings")
    end
  else
    print("Settings dont exist")
    return nil
  end

  env = nil
  local platformMap = Manifest.getPlatforms(manifest)
  env = Settings.getParticleEnv(platformMap, settings)
  return settings_path
end

local function setMappings()
  vim.keymap.set("n", "<leader><leader>p", ":lua require'particle'.project()<cr>", { nowait=false, noremap=true, silent=true, desc = "Launch Particle.nvim local project configuration" })
end

local function get_env()
  return settings, env
end

function M.setup()
  setMappings()
  Utils.ensure_directory(Constants.DataDir)
  Utils.ensure_directory(Constants.OSCCJsonDir)
  manifest = Manifest.setup()
  project_root = LoadSettings(manifest)
  if project_root == nil then
    project_root = M.find_project_root()
  end
  print("project root " .. project_root)
  if settings == nil then
    return
  end
  Commands.setup(get_env)
end

function M.project()
  M.setup()
  CreateMainMenu(manifest)
end

print("Hello from particle.nvim")

return M
