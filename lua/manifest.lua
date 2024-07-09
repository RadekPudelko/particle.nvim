-- check vscode extension version
--curl -X POST -H 'Accept: application/json; charset=utf-8; api-version=7.2-preview.1' -H 'Content-Type: application/json' -d '{"filters": [{"criteria": [{"filterType": 7, "value": "particle.particle-vscode-core"}]}], "flags": 512}' https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery
---- with asset urls
--curl -X POST -H 'Accept: application/json; charset=utf-8; api-version=7.2-preview.1' -H 'Content-Type: application/json' -d '{"filters": [{"criteria": [{"filterType": 7, "value": "particle.particle-vscode-core"}]}], "flags": 514}' https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery

-- To download particle vscode extension
-- curl https://particle.gallery.vsassets.io/_apis/public/gallery/publisher/particle/extension/particle-vscode-core/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage -o particle.tar.gz

local log = require("log")
local api = vim.api
local Constants = require("constants")

local M = {}

-- local manifest

-- Find the Particle's manifest file from within their toolchain package in the
-- particle workbench core vscode extension
-- Used to load particle platforms, ids, device os versions and more
local function findParticleManifest(path)
  -- TODO: convert to be OS agnostic
  local result = api.nvim_call_function('systemlist', {
    "find " .. path .. " -name manifest.json | grep toolchain-manager"
  })
  if #result == 0 then
    log:error("Failed to load particle manifset")
    return nil
    -- elseif #result > 1 then
    --     print("Found multiple particle manifests")
  end
  local particleManifestPath = result[1]
  log:info("Loading particle manifset from %s", result[1])
  return particleManifestPath
end

local function loadParticleManifest(path)
  local file = io.open(path, "r")
  if not file then return end

  local txt = file:read("*a")
  file:close()

  return vim.json.decode(txt)
end

function M.setup()
  local path = findParticleManifest(Constants.VSCodeExtensionDir)
  return loadParticleManifest(path)
end

function M.getPlatforms(manifest)
  local platforms = {}
  for i = 1, #manifest["platforms"] do
    local id = manifest["platforms"][i]["id"]
    local name = manifest["platforms"][i]["name"]
    platforms[id] = name
    platforms[name] = id
  end
  return platforms
end

-- "platforms": [
--     12,
--     13,
--     15,
--     23,
--     25,
--     26
-- ],
-- "firmware": "deviceOS@6.1.0",
-- "compilers": "gcc-arm@10.2.1",
-- "tools": "buildtools@1.1.1",
-- "scripts": "buildscripts@1.15.0",
-- "debuggers": "openocd@0.11.0-particle.4",
function M.getToolchain(manifest, version)
  for i = 1, #manifest["toolchains"] do
    local firmware = manifest["toolchains"][i]["firmware"]
    local desiredVersionString = "deviceOS@" .. version
    if firmware == desiredVersionString then
      return manifest["toolchains"][i]
    end
  end
end

function M.getFirmwareVersions(manifest)
  local versions = {}
  for i = 1, #manifest["toolchains"] do
    local version = manifest["toolchains"][i]["firmware"]
    versions[i] = string.match(version, "@(.*)")
  end
  return versions
end

function M.getFirmwareBinaryUrl(manifest, version)
  -- local url = particleBinariesUrl .. version .. ".tar.gz"
  for i = 1, #manifest["firmware"] do
    local manifestVersion = manifest["firmware"][i]["version"]
    if manifestVersion == version then
      return manifest["firmware"][i]["url"]
    end
  end
  return nil
end

-- Returns true if the platform is valid for the device_os
-- TODO: Add config option to remove this check, ex 5.7.0 can't be compiled for anything, because its missing from manifest.json
function M.is_platform_valid_for_device_os(manifest, device_os, platform)
  local toolchain = M.getToolchain(manifest, device_os)
  if toolchain == nil then
    return false
  end

  local platformMap = M.getPlatforms(manifest)
  for _, platformId in ipairs(toolchain["platforms"]) do
    if platform == platformMap[platformId] then
      return true
    end
  end
  return false
end

return M

