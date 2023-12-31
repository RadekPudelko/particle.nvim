-- check vscode extension version
--curl -X POST -H 'Accept: application/json; charset=utf-8; api-version=7.2-preview.1' -H 'Content-Type: application/json' -d '{"filters": [{"criteria": [{"filterType": 7, "value": "particle.particle-vscode-core"}]}], "flags": 512}' https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery
---- with asset urls
--curl -X POST -H 'Accept: application/json; charset=utf-8; api-version=7.2-preview.1' -H 'Content-Type: application/json' -d '{"filters": [{"criteria": [{"filterType": 7, "value": "particle.particle-vscode-core"}]}], "flags": 514}' https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery

-- To download particle vscode extension
-- curl https://particle.gallery.vsassets.io/_apis/public/gallery/publisher/particle/extension/particle-vscode-core/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage -o particle.tar.gz

local api = vim.api

local M = {}

local vscodePath = "~/.vscode/extensions"

local manifest

-- Find the Particle's manifest file from within their toolchain package in the
-- particle workbench core vscode extension
-- Used to load particle platforms, ids, device os versions and more
local function findParticleManifest(path)
    local result = api.nvim_call_function('systemlist', {
        "find " .. path .. " -name manifest.json | grep toolchain-manager"
    })
    if #result == 0 then
        print("Failed to find particle manifest")
        return nil
    elseif #result > 1 then
        print("Found multiple particle manifests")
    end
    local particleManifestPath = result[1]
    print("Using particle manifset from " .. result[1])
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
    local path = findParticleManifest(vscodePath)
    manifest = loadParticleManifest(path)

end

function M.getPlatforms()
    local platforms = {}
    for i = 1, #manifest["platforms"] do
        local id = manifest["platforms"][i]["id"]
        platforms[id] = manifest["platforms"][i]["name"]
    end
    return platforms
end

function M.getFirmwareVersions()
    local versions = {}
    for i = 1, #manifest["toolchains"] do
        local version = manifest["toolchains"][i]["firmware"]
        versions[i] = string.match(version, "@(.*)")
    end
    return versions
end

function M.getFirmwareBinaryUrl(version)
    -- local url = particleBinariesUrl .. version .. ".tar.gz"
    for i = 1, #manifest["firmware"] do
        local manifestVersion = manifest["firmware"][i]["version"]
        if manifestVersion == version then
            return manifest["firmware"][i]["url"]
        end
    end
    return nil
end

return M

