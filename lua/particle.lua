local utils = require "utils"
local api = vim.api
local buf, win

-- A few places to pull particle platforms from
-- toolchain modules folder
---- probably not this one, since the names dont match up with actual platforms
-- toolchain build/platform.mk
---- akward to parse
-- release title (needs to be lower cased + spaces removed)
---- trustworthy?
-- ~/.vscode/extensions/particle.particle-vscode-core-1.16.10/node_modules/@particle/device-constants/dist/js/constants.json
---- For display names, which can be corresponded to platform
-- toolchain .workbench/manifest.json for ids
-- vscode extension: ~/.vscode/extensions/particle.particle-vscode-core-1.16.10/node_modules/@particle/toolchain-manager/manifest.json
---- contains everything


-- where the toolchains will be installed
local toolchainFolder = "./toolchains/"
local manifestFile = "./manifest.json"

-- line in the buffer where data is loaded, along with top of what user can reach
local cursorStart = 3

--0=not loaded, 1=versions buffer view, 2=version description buffer view
local state = 0;

--table of device os tags
local versions = {}
local isInstalled = {}
local tarballUrls = {}
local versions_loaded = false

local version

local platforms = {}

local function center(str)
    local width = api.nvim_win_get_width(0)
    local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
    return string.rep(' ', shift) .. str
end

local function openWindow()
    buf = api.nvim_create_buf(false, true)
    local border_buf = api.nvim_create_buf(false, true)

    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    -- api.nvim_buf_set_option(buf, 'filetype', 'particle')
    api.nvim_buf_set_option(buf, 'filetype', 'markdown')

    local width = api.nvim_get_option("columns")
    local height = api.nvim_get_option("lines")

    local win_height = math.ceil(height * 0.8 - 4)
    local win_width = math.ceil(width * 0.8)
    local row = math.ceil((height - win_height) / 2 - 1)
    local col = math.ceil((width - win_width) / 2)

    local border_opts = {
        style = "minimal",
        relative = "editor",
        width = win_width + 2,
        height = win_height + 2,
        row = row - 1,
        col = col - 1
    }

    local opts = {
        style = "minimal",
        relative = "editor",
        width = win_width,
        height = win_height,
        row = row,
        col = col
    }

    local border_lines = { '╔' .. string.rep('═', win_width) .. '╗' }
    local middle_line = '║' .. string.rep(' ', win_width) .. '║'
    for i=1, win_height do
        table.insert(border_lines, middle_line)
    end
    table.insert(border_lines, '╚' .. string.rep('═', win_width) .. '╝')
    api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

    local border_win = api.nvim_open_win(border_buf, true, border_opts)
    win = api.nvim_open_win(buf, true, opts)
    api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "'..border_buf)

    api.nvim_win_set_option(win, 'cursorline', true)

    api.nvim_buf_set_lines(buf, 0, -1, false, { center('Particle.nvim'), '', ''})
    state = 1
    -- api.nvim_buf_add_highlight(buf, -1, 'WhidHeader', 0, 0, -1)
end

local function updateView()
    api.nvim_buf_set_option(buf, 'modifiable', true)

    if not versions_loaded then
        local result = api.nvim_call_function('system', {
            "curl -Ls https://api.github.com/repos/particle-iot/device-os/tags"
        })

        -- parse json response if there was one
        local json = nil
        if #result ~= 0 then
            json = vim.json.decode(result)
        end

        -- Curl failed due to network or no tag results in the curl
        -- expecting 30 tags by default
        if #result == 0 or json[1] == nil then
            versions[1] = 'Failed to curl tags from https://api.github.com/repos/particle-iot/device-os/tags'
        else
            versions = {}
            for i=1, #json do
                versions[i] = json[i]["name"]
                tarballUrls[i] = json[i]["zipball_url"]
            end
            versions_loaded = true
        end
    end


    -- TODO: figure out better check for installation, maybe a file I create?
    for i=1, #versions do
        local file = toolchainFolder .. versions[i]
        -- TODO: figure out possible errs and how to handle
        local exists, err = utils.directoryExists(file)
        -- print("err ".. err)
        isInstalled[i] = exists
    end

    local myLines = {}
    myLines[1] = "## Installed"
    local line = 2
    for i=1, #versions do
        if(isInstalled[i]) then
            myLines[line] = versions[i]
            line = line + 1
        end
    end

    myLines[line] = ""
    line = line + 1

    myLines[line] = "## Available"
    line = line + 1
    for i=1, #versions do
        if(not isInstalled[i]) then
            myLines[line] = versions[i]
            line = line + 1
        end
    end



    -- api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, versions)
    api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, myLines)

    -- api.nvim_buf_add_highlight(buf, -1, 'particleSubHeader', 1, 0, -1)
    api.nvim_buf_set_option(buf, 'modifiable', false)
    state = 1
end

local function loadPlatforms()
    local file = io.open(manifestFile, "r")
    if not file then return end
    local manifestText = file:read("*a")
    file:close()

    platforms = {}
    local json = vim.json.decode(manifestText)
    for i = 1, #json["platforms"] do
        local id = json["platforms"][i]["id"]
        platforms[id] = json["platforms"][i]["name"]
    end
end

local function loadReleaseBody()
    if state ~= 1 then return end

    api.nvim_buf_set_option(buf, 'modifiable', true)

    local cur_line_num = vim.fn.getcurpos()[2];
    local version = vim.fn.getline(cur_line_num)
    if #version == 0 then return end

    local result = api.nvim_call_function('system', {
        "curl -Ls https://api.github.com/repos/particle-iot/device-os/releases/tags/"..version
    })

    local json = vim.json.decode(result)
    local body = json["body"]
    local lines = {}
    for s in body:gmatch("[^\r\n]+") do
        table.insert(lines, s)
    end

    api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, lines)
    api.nvim_set_option_value('filetype', 'markdown', {['buf']=buf})
    -- api.nvim_set_option_value('startofline', true, {['win']=win})
    -- api.nvim_set_option_value('wrap', true, {['buf']=buf})
    api.nvim_buf_set_option(buf, 'modifiable', false)
    state = 2
end

-- May need to determine what the folder will be called by string building
-- or use tar command to rename the top level folder during decompression
-- TODO: Probably convert this to somesort of job that runs a call back to update the main view at the end of installation
local function installRelease()
    if state ~= 1 then return end

    local cur_line_num = vim.fn.getcurpos()[2];
    local version = vim.fn.getline(cur_line_num)

    -- Ignore lines that do not have a version (blank or header)
    if #version == 0 then return end
    if(string.lower(string.sub(version, 1, 1)) ~= 'v') then return end

    local index = 0
    for i = 1, #versions do
       if version == versions[i] then
           index = i
           break
       end
    end

    if index == 0 then
        -- Should never happen
        print("Unable to find " .. version)
        return
    end

    local file = toolchainFolder .. version
    if isInstalled[index] then
        print(version .. " is already installed at " .. file)
        return
    end

    local url = tarballUrls[index]
    local tarfile = file .. ".tar.gz"

    local result = api.nvim_call_function('system', {
        "wget -cO - " .. url .. " > " .. tarfile
    })

    -- TODO: check if the downloaded file exists
    result = api.nvim_call_function('system', {
        "mkdir " .. file
    })

    local cmd = "tar -xf " .. tarfile .. " -C " .. file .. " --strip-components 1"
    result = api.nvim_call_function('system', {
        cmd
    })

    result = api.nvim_call_function('system', {
        'rm ' .. tarfile
    })

    updateView()
end

local function uninstallRelease()
    if state ~= 1 then return end

    local cur_line_num = vim.fn.getcurpos()[2];
    local version = vim.fn.getline(cur_line_num)

    -- Ignore lines that do not have a version (blank or header)
    if #version == 0 then return end
    if(string.lower(string.sub(version, 1, 1)) ~= 'v') then return end

    local index = 0
    for i = 1, #versions do
       if version == versions[i] then
           index = i
           break
       end
    end

    if index == 0 then
        -- Should never happen
        print("Unable to find " .. version)
        return
    end

    if not isInstalled[index] then
        print("Not installed")
        return
    end

    local file = toolchainFolder .. version

    local confirmation
    repeat
        confirmation = vim.fn.input("Confirm rm -rf on " .. file .. " (y/n): ")
    until(confirmation == 'y') or (confirmation == 'n')

    -- clear command area
    vim.cmd("echon ' '")

    if(confirmation == 'n') then return end

    local result = api.nvim_call_function('system', {
        "rm -rf " .. file
    })

    if not utils.directoryExists(file) then
        -- print(version .. " was successfully removed")
        isInstalled[index] = false
        updateView()
    else
        -- print("Failed to remove " .. file)
    end
end

local function deviceOSView()
    if state ~= 1 then return end

    local cur_line_num = vim.fn.getcurpos()[2];
    local currentLineText = vim.fn.getline(cur_line_num)

    -- Ignore lines that do not have a version (blank or header)
    if #currentLineText == 0 then return end
    if(string.lower(string.sub(currentLineText, 1, 1)) ~= 'v') then return end

    local index = 0
    for i = 1, #versions do
       if currentLineText == versions[i] then
           index = i
           break
       end
    end

    if index == 0 then
        -- Should never happen
        print("Unable to find " .. version)
        return
    end

    if not isInstalled[index] then return end

    version = currentLineText

    local toolchainManifest = toolchainFolder .. version .. "/.workbench/manifest.json"
    local file = io.open(toolchainManifest, "r")
    if not file then return end
    local manifestText = file:read("*a")
    file:close()

    -- TODO: Set up some sort of test or checks here to make sure the file format is as
    -- we expect it to be
    local json = vim.json.decode(manifestText)
    local toolchainPlatformIds = json["toolchains"][1]["platforms"]

    -- TODO: The line setting is not working correctly
    local myLines = {}
    local line = 1
    myLines[line] = "Device OS: " .. version
    line = line + 1
    myLines[line] = ""
    line = line + 1

    for i=1, #toolchainPlatformIds do
        local id = toolchainPlatformIds[i]
        myLines[line] = platforms[id]
        line = line + 1
    end

    api.nvim_buf_set_option(buf, 'modifiable', true)
    api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, myLines)

    api.nvim_buf_set_option(buf, 'modifiable', false)
    state = 3

    -- utils.printTable(json["platforms"])
end

local function deviceOSCompile()
    if state ~= 3 then return end

    local cur_line_num = vim.fn.getcurpos()[2];
    local currentLineText = vim.fn.getline(cur_line_num)

    if #currentLineText == 0 then return end

    local isValidPlatform = false
    for id, name in pairs(platforms) do
        if currentLineText == name then
            isValidPlatform = true
            break
        end
    end
    if not isValidPlatform then return end

end

local function closeWindow()
    api.nvim_win_close(win, true)
    state = 0
end

-- Limit cursor movement to within the version section
local function moveCursor()
    local new_pos = math.max(cursorStart, api.nvim_win_get_cursor(win)[1] - 1)
    api.nvim_win_set_cursor(win, {new_pos, 0})
end

local function setMappings()
    local mappings = {
        ['<cr>'] = 'loadReleaseBody()',

        -- hl are restricting movement in the buffers
        h = 'updateView()',
        l = 'updateView()',
        q = 'closeWindow()',
        k = 'moveCursor()',
        i = 'installRelease()',
        X = 'uninstallRelease()',
        c = 'deviceOSView()',
        m = 'deviceOSCompile()'
    }

    for k,v in pairs(mappings) do
        api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"particle".'..v..'<cr>', {
            nowait = true, noremap = true, silent = true
        })
    end

    -- these are currently restricting what can be done in the buffer, no gg for instance
    -- local other_chars = {
        --   'a', 'b', 'c', 'd', 'e', 'f', 'g', 'i', 'n', 'o', 'p', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
        -- }
        -- for k,v in ipairs(other_chars) do
        --   api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
        --   api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
        --   api.nvim_buf_set_keymap(buf, 'n',  '<c-'..v..'>', '', { nowait = true, noremap = true, silent = true })
        -- end
    end


local function particle()
    if state ~= 0 then return end
    openWindow()
    loadPlatforms()
    setMappings()
    updateView()
    api.nvim_win_set_cursor(win, {cursorStart, 0})
end

return {
    particle = particle,
    updateView = updateView,
    moveCursor = moveCursor,
    loadReleaseBody = loadReleaseBody,
    closeWindow = closeWindow,
    installRelease = installRelease,
    uninstallRelease = uninstallRelease,
    deviceOSView = deviceOSView,
    deviceOSCompile= deviceOSCompile
}

