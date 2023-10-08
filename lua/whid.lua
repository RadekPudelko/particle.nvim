local utils = require "particle_utils"
--- Add Descriptions of releases
local api = vim.api
local buf, win

-- line in the buffer where data is loaded, along with top of what user can reach
local cursorStart = 3

--0=not loaded, 1=versions buffer view, 2=version description buffer view
local state = 0;

--table of device os tags
local versions = {}
local versions_loaded = false

local function center(str)
  local width = api.nvim_win_get_width(0)
  local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
  return string.rep(' ', shift) .. str
end

local function open_window()
  buf = vim.api.nvim_create_buf(false, true)
  local border_buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'whid')

  local width = vim.api.nvim_get_option("columns")
  local height = vim.api.nvim_get_option("lines")

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
  vim.api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

  local border_win = vim.api.nvim_open_win(border_buf, true, border_opts)
  win = api.nvim_open_win(buf, true, opts)
  api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "'..border_buf)

  vim.api.nvim_win_set_option(win, 'cursorline', true)

  api.nvim_buf_set_lines(buf, 0, -1, false, { center('Particle.nvim'), '', ''})
  state = 1
  -- api.nvim_buf_add_highlight(buf, -1, 'WhidHeader', 0, 0, -1)
end

local function update_view()
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)

    if not versions_loaded then
        local result = vim.api.nvim_call_function('system', {
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
                local version = json[i]["name"]
                versions[i] = version
            end
            versions_loaded = true
        end
    end
    api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, versions)

    -- api.nvim_buf_add_highlight(buf, -1, 'whidSubHeader', 1, 0, -1)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    state = 1
end

local function load_release()
    if state ~= 1 then return end

  vim.api.nvim_buf_set_option(buf, 'modifiable', true)

  local cur_line_num = vim.fn.getcurpos()[2];
  local version = vim.fn.getline(cur_line_num)
  if #version == 0 then return end

  local result = vim.api.nvim_call_function('system', {
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
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  state = 2
end


local function close_window()
  api.nvim_win_close(win, true)
  state = 0
end

local function open_file()
  local str = api.nvim_get_current_line()
  close_window()
  api.nvim_command('edit '..str)
end

local function move_cursor()
  local new_pos = math.max(cursorStart, api.nvim_win_get_cursor(win)[1] - 1)
  api.nvim_win_set_cursor(win, {new_pos, 0})
end

local function set_mappings()
  local mappings = {
    ['['] = 'update_view(-1)',
    [']'] = 'update_view(1)',
    -- ['<cr>'] = 'open_file()',
    ['<cr>'] = 'load_release()',

    -- hl are restricting movement in the buffers
    h = 'update_view()',
    l = 'update_view(1)',
    q = 'close_window()',
    k = 'move_cursor()'
  }

  for k,v in pairs(mappings) do
    api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"whid".'..v..'<cr>', {
        nowait = true, noremap = true, silent = true
      })
  end

  -- these are currently restricting what can be done in the buffer, no gg for instance
  local other_chars = {
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'i', 'n', 'o', 'p', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
  }
  for k,v in ipairs(other_chars) do
    api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n',  '<c-'..v..'>', '', { nowait = true, noremap = true, silent = true })
  end
end

local function whid()
  open_window()
  set_mappings()
  update_view()
  api.nvim_win_set_cursor(win, {cursorStart, 0})
end

return {
  whid = whid,
  -- update_view = update_view,
  update_view = update_view,
  open_file = open_file,
  move_cursor = move_cursor,
  load_release = load_release,
  close_window = close_window
}
