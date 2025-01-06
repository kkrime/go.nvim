local save_location = vim.fn.expand("$HOME/.go_buildtargets.json")
local popup = require("plenary.popup")

local get_project_root
local select_buildtarget_callback
local close_menu_keys = { '<Esc>' }

local menu = 'menu'
local items = 'items'
local height = 'height'
local idx = 'idx'
local location = 'location'

local M = {}

---@type cache
M._cache = {}

---@type current_buildtargets
M._current_buildtargets = {}

---@type collisions
M._collisions = {}

function M.setup(cfg)
  if cfg and cfg.get_project_root_func then
    get_project_root = cfg.get_project_root_func
    assert(type(get_project_root) == "function", "buildtargets: get_project_root_func must be a function")

    select_buildtarget_callback = cfg.select_buildtarget_callback
    if select_buildtarget_callback then
      assert(type(select_buildtarget_callback) == "function",
        "buildtargets: select_buildtarget_callback must be a function")
    end

    if cfg.close_menu_keys then
      close_menu_keys = cfg.close_menu_keys
      assert(type(close_menu_keys) == "table", "buildtargets: close_menu_keys be a table")
    end

    if cfg.buildtargets_save_location then
      save_location = cfg.buildtargets_save_location
    end
    load_buildtargets()
  end
end

--- Checks if buildtargets should be used or not
---
---@return boolean # true if buildtargest should be used, false if buildtargets should not be used
function M.use_buildtargets()
  return get_project_root ~= nil
end

--- updates the current_buildtarget
---
---@param buildtarget target_name
---@param project_root project_root
---@return boolean # if buildtarget updated to new value, false if buildtraget already set to buildtarget
local function update_current_buildtarget(buildtarget, project_root)
  local current_buildtarget_backup = M._current_buildtargets[project_root]
  if current_buildtarget_backup ~= buildtarget then
    M._current_buildtargets[project_root] = buildtarget
    if select_buildtarget_callback then
      select_buildtarget_callback()
    end
    return true
  end
  return false
end

--- returns the current buildtarget
--- if there is only one buildtarget for a project, will return nil
---
--- @return (target_name|nil)
function M.get_current_buildtarget()
  local project_root = get_project_root()
  local current_target = M._current_buildtargets[project_root]
  if current_target then
    if #M._cache[project_root][menu][items] > 1 then
      return current_target
    end
  end
  return nil
end

local function get_target_name(location)
  local target_name = location:match("^.*/(.*)%.go$")
  if target_name ~= "main" then
    return target_name
  end

  target_name = location:match("^.*/(.*)/.*$")
  return target_name
end

local function is_file_a_target(filelocation)
  local close_buffer = false
  local bufnr = vim.fn.bufnr(filelocation)
  if bufnr == -1 then
    vim.api.nvim_command('badd ' .. filelocation)
    bufnr = vim.fn.bufnr(filelocation)
    close_buffer = true
  end

  local parser = vim.treesitter.get_parser(bufnr, "go")
  local tree = parser:parse()[1]

  -- search for file with 'package main' and 'func main()'
  local query = vim.treesitter.query.parse(
    "go",
    [[
      (package_clause
        (package_identifier) @main.package)
      (function_declaration
        name: (identifier) @main.function
        parameters: (parameter_list) @main.function.parameters
        !result
      (#eq? @main.package "main")
      (#eq? @main.function "main"))
      (#eq? @main.function.parameters "()")
    ]])

  local ts_query_match = 0
  for _, _, _, _ in query:iter_captures(tree:root(), bufnr, nil, nil) do
    ts_query_match = ts_query_match + 1
  end

  if close_buffer then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  if ts_query_match == 3 then
    return true
  end
  return false
end

local function get_project_targets(project_root, bufnr)
  bufnr = bufnr or 0
  local ms = require('vim.lsp.protocol').Methods
  local method = ms.workspace_symbol

  local result = vim.lsp.buf_request_sync(bufnr, method, { query = "main" }, 5000)
  if not result then
    return "nil result from Language Server"
  end

  local menu_items = {}
  local menu_width = 0
  local menu_height = 0
  local targets = {}
  if result then
    for _, resss in pairs(result) do
      for _, ress in pairs(resss) do
        for _, res in pairs(ress) do
          if res.name == "main" then
            -- filter functions only (vlaue 12)
            if res.kind == 12 then
              local filelocation = vim.uri_to_fname(res.location.uri)
              if not vim.startswith(filelocation, project_root) then
                goto continue
              end

              if is_file_a_target(filelocation) then
                menu_height = menu_height + 1
                local target_name = get_target_name(filelocation)
                M._add_target_to_cache(targets, target_name, { idx = menu_height, location = filelocation })
                if #target_name > menu_width then
                  menu_width = #target_name
                end
                menu_items[menu_height] = target_name
              end
            end
          end
          ::continue::
        end
      end
    end
  end
  if menu_height > 0 then
    targets[menu] = { items = menu_items, width = menu_width, height = menu_height }
    M._add_resolved_target_name_collisions(targets, project_root)
    if M._cache[project_root] then
      -- this is a refresh
      M._refresh_project_buildtargets(targets, project_root)
    else
      M._cache[project_root] = targets
      save_buildtargets()
    end
    -- vim.notify(vim.inspect({ "targets", targets = targets }))
  else
    M._cache[project_root] = nil
    -- TODO think about this
    M._current_buildtargets[project_root] = nil
    -- TODO think about this
    save_buildtargets()
    return "no build targets found"
  end
end

local function update_buildtarget_map(selection, project_root)
  local current_buildtarget_changed = update_current_buildtarget(selection, project_root)

  local selection_idx = M._cache[project_root][selection][idx]
  if selection_idx == 1 then
    if current_buildtarget_changed then
      save_buildtargets()
    end
    return
  end

  local selection_backup = M._cache[project_root][selection]
  selection_backup[idx] = 1
  M._cache[project_root][selection] = nil
  M._cache[project_root][menu] = nil

  local menu_items = {}
  local menu_width = #selection
  local menu_height = 1

  for target_name, target_details in pairs(M._cache[project_root]) do
    local target_idx = target_details[idx]
    if target_idx < selection_idx or target_idx == 2 then
      target_idx = target_idx + 1
      target_details[idx] = target_idx
    end
    menu_items[target_idx] = target_name
    menu_height = menu_height + 1
    if #target_name > menu_width then
      menu_width = #target_name
    end
  end
  M._cache[project_root][selection] = selection_backup
  menu_items[1] = selection

  M._cache[project_root][menu] = { items = menu_items, width = menu_width, height = menu_height }

  save_buildtargets()
  -- require('lualine').refresh()
end

-- local flash_menu = function(project_root)
local function flash_menu(project_root)
  vim.cmd("set modifiable")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
  vim.cmd('redraw')
  vim.wait(20)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, M._cache[project_root][menu][items])
  vim.cmd("set nomodifiable")
end

-- local menu_* vars are used to keep manage menu
local menu_visible_for_proj = nil
local menu_winnr = nil
local menu_coroutines = {}
local show_menu = function(co)
  local project_root = get_project_root()

  -- if satement below needed for race condition
  if menu_visible_for_proj then
    -- menu is visible for current project
    if menu_visible_for_proj == project_root then
      table.insert(menu_coroutines, co)
      vim.api.nvim_set_current_win(menu_winnr)
      flash_menu(project_root)
      return
    end
    -- user request menu for different project
    -- close prevoius menu
    vim.api.nvim_win_close(menu_winnr, true)
  end

  table.insert(menu_coroutines, co)
  menu_visible_for_proj = project_root

  -- capture bufnr of current buffer for scan_project()
  local bufnr_called_from = vim.api.nvim_get_current_buf()

  local user_selection

  local menu_opts = M._cache[project_root][menu]
  local menu_height = menu_opts.height
  local menu_width = menu_opts.width
  menu_winnr = popup.create(menu_opts.items, {
    title = {
      { pos = "N", text = "Select Build Target", },
      { pos = "S", text = "Press 'r' to Refresh" } },
    cursorline = true,
    line = math.floor(((vim.o.lines - menu_height) / 5.0) - 1),
    col = math.floor((vim.o.columns - menu_width) / 2),
    minwidth = 30,
    minheight = 13,
    borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
    callback = function(_, sel)
      local selection = vim.api.nvim_get_current_line()
      user_selection = M._cache[project_root][selection][location]
      update_buildtarget_map(selection, project_root)
    end
  })

  local bufnr = vim.api.nvim_win_get_buf(menu_winnr)

  -- disable insert mode
  vim.cmd("set nomodifiable")
  -- disable the cursor; https://github.com/goolord/alpha-nvim/discussions/75
  local hl = vim.api.nvim_get_hl_by_name('Cursor', true)
  hl.blend = 100
  vim.api.nvim_set_hl(0, 'Cursor', hl)
  vim.opt.guicursor:append('a:Cursor/lCursor')

  -- set Ecs to close menu
  for _, key in pairs(close_menu_keys) do
    vim.api.nvim_buf_set_keymap(bufnr, "n", key, ":q<CR>", { silent = false })
  end

  local err

  -- refresh menu
  vim.keymap.set("n", "r", function()
    vim.cmd("set modifiable")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Refreshing..." })
    vim.cmd('redraw')
    err = get_project_targets(project_root, bufnr_called_from)
    if err then
      vim.api.nvim_win_close(menu_winnr, true)
      vim.notify("error refreshing build targets: " .. err, vim.log.levels.ERROR)
      return
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, M._cache[project_root][menu][items])
    vim.cmd("set nomodifiable")
  end, { buffer = bufnr, silent = true })

  -- leave menu window
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    callback = function()
      vim.cmd("set modifiable")
      hl.blend = 0
      vim.api.nvim_set_hl(0, 'Cursor', hl)
      -- if you leave the menu buffer, then close menu window
      vim.schedule(function()
        if menu_visible_for_proj then
          vim.api.nvim_win_close(menu_winnr, true)
        end
      end)
    end,
  })

  -- close menu window
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(menu_winnr),
    callback = function()
      for _, cr in ipairs(menu_coroutines) do
        coroutine.resume(cr, user_selection, err)
      end
      menu_coroutines = {}
      menu_visible_for_proj = nil
    end,
  })

  return bufnr
end

function M.get_current_buildtarget_location()
  local project_root = get_project_root()
  local current_target = M._current_buildtargets[project_root]
  if current_target then
    local buildtarget_location = M._cache[project_root][current_target][location]
    return buildtarget_location
  end
  return nil
end

function M.select_buildtarget(co)
  -- TODO check being called from *.go file
  local project_root = get_project_root()
  if not M._cache[project_root] then
    -- project_root hasn't been scanned yet
    local err = get_project_targets(project_root)
    if err then
      vim.notify("error finding build targets: " .. err, vim.log.levels.ERROR)
      return nil, err
    end
  end

  if co then
    local targets_names = M._cache[project_root][menu][items]
    if #targets_names == 1 then
      -- if only one build target, send build target location
      local target_name = targets_names[1]
      -- M._current_buildtargets[project_root] = target_name
      update_current_buildtarget(target_name, project_root)
      local target_location = M._cache[project_root][target_name][location]
      vim.schedule(function()
        coroutine.resume(co, target_location, nil)
      end)
      return
    end
  end

  -- if multiple build targets, then launch menu and ask user to select
  show_menu(co)
end

local function match_location(original_dir, refresh_dir)
  local original_loc = original_dir:match('^(.*)/.*$')
  local refresh_loc = refresh_dir:match('^(.*)/.*$')
  if original_loc == refresh_loc then
    return true
  end
  return false
end

-- TODO rename this
M._refresh_project_buildtargets = function(refresh, project_root)
  local original = M._cache[project_root]

  local updated_current_buildtarget
  local current_buildtarget_location
  local current_buildtarget = M._current_buildtargets[project_root]
  if current_buildtarget then
    current_buildtarget_location = original[current_buildtarget][location]:match('^(.*)/.*$')
  end

  local idxs = {}
  local backup_menu_items = original[menu][items]
  original[menu] = nil
  refresh[menu] = nil
  for _, refresh_target_details in pairs(refresh) do
    local ref_dir = refresh_target_details[location]
    refresh_target_details[idx] = nil
    for orig_target_name, orig_target_details in pairs(original) do
      local orig_dir = orig_target_details[location]
      if match_location(orig_dir, ref_dir) then
        refresh_target_details[idx] = orig_target_details[idx]
        table.insert(idxs, refresh_target_details[idx])
        original[orig_target_name] = nil
        break
      end
    end
  end

  table.sort(idxs)

  local idx_target_change = {}
  for i = 1, (#idxs) do
    local idx = idxs[i]
    idx_target_change[idx] = i
  end

  local menu_height = #idxs
  local menu_items = {}
  local menu_width = 0
  for target_name, target_details in pairs(refresh) do
    local new_target_idx
    local target_idx = target_details[idx]
    if not target_idx then
      menu_height = menu_height + 1
      new_target_idx = menu_height
    else
      new_target_idx = idx_target_change[target_idx]
      if current_buildtarget then
        local target_buildtarget = target_details[location]:match('^(.*)/.*$')
        if current_buildtarget_location == target_buildtarget then
          updated_current_buildtarget = target_name
          current_buildtarget = nil
        end
      end
    end
    target_details[idx] = new_target_idx
    menu_items[new_target_idx] = target_name
    if #target_name > menu_width then
      menu_width = #target_name
    end
  end

  -- M._current_buildtargets[project_root] = updated_current_buildtarget
  update_current_buildtarget(updated_current_buildtarget, project_root)
  refresh[menu] = { items = menu_items, width = menu_width, height = menu_height }

  M._cache[project_root] = refresh
  -- TODO think about this...
  if not vim.deep_equal(backup_menu_items, refresh[menu][items]) then
    save_buildtargets()
  end
end

function create_target_name_resolution_string(target_location, project_location)
  local new_target_name_resolution_string = string.sub(target_location, #project_location + 1, #target_location)
  local truncate = 3 -- '.go postfix'
  local ends_in_main = string.sub(new_target_name_resolution_string, #new_target_name_resolution_string - 7,
    #new_target_name_resolution_string)
  if ends_in_main == '/main.go' then
    truncate = truncate + 5 -- '/main'
  end
  new_target_name_resolution_string = string.sub(new_target_name_resolution_string, 1,
    #new_target_name_resolution_string - truncate)
  return new_target_name_resolution_string
end

local expand_target_name = function(target_resolution_details)
  local trd           = target_resolution_details
  local regex_start   = '^.*/('
  local regex_end     = ')$'

  trd.capture_pattern = trd.capture_pattern .. '/.*'
  local regex         = regex_start .. trd.capture_pattern .. regex_end
  local target_name   = trd.resolution_string:match(regex)
  trd.target_name     = target_name
end

local can_target_name_expand = function(target_resolution_details)
  local target_resolution_string_length = #target_resolution_details.resolution_string - 1
  local target_name_length = #target_resolution_details.target_name
  return target_resolution_string_length ~= target_name_length
end

local resolve_target_name_collision = function(target, target_details, project_root)
  local collisions                    = M._collisions[project_root]
  local project_location              = collisions.project_location
  local new_target_resolution_string  = create_target_name_resolution_string(target_details[location], project_location)

  local new_target_resolution_details = {
    target_name = target,
    target_details = target_details,
    resolution_string = new_target_resolution_string,
    capture_pattern = '.*'
  }
  local new_target_name               = new_target_resolution_details.target_name

  for _, target_resolution_details in ipairs(collisions[target]) do
    local target_name = target_resolution_details.target_name

    while true do
      local extend_target_name = false
      local extend_new_target_name = false

      if #target_name == #new_target_name then
        if target_name == new_target_name then
          -- vim.notify(vim.inspect({ "1", new_target_resolution_details, target_resolution_details }))

          if #target_resolution_details['resolution_string'] == #new_target_resolution_details['resolution_string'] and
              target_resolution_details['resolution_string'] == new_target_resolution_details['resolution_string'] then
            -- corner case
            local target_location = target_resolution_details['target_details'][location]
            if string.sub(target_location, #target_location - 6) ~= "main.go" then
              target_resolution_details['add_filename_extension'] = true
            else
              new_target_resolution_details['add_filename_extension'] = true
            end
            -- collision resolved
            break
          else
            if can_target_name_expand(target_resolution_details) then
              -- vim.notify(vim.inspect({ "can_target_name_expand_", target_resolution_details }))
              extend_target_name = true
            end
            if can_target_name_expand(new_target_resolution_details) then
              -- vim.notify(vim.inspect({ "can_new_target_name_expand", can_new_target_name_expand }))
              extend_new_target_name = true
            end
          end
        else
          -- collision resolved
          break
        end
      elseif #target_name > #new_target_name then
        -- vim.notify(vim.inspect({ "2" }))
        if can_target_name_expand(new_target_resolution_details) and
            can_target_name_expand(target_resolution_details) and
            vim.endswith(target_name, new_target_name) then
          extend_new_target_name = true
        else
          -- collision resolved
          break
        end
      else -- #new_target_name > #target_name
        if can_target_name_expand(target_resolution_details) and
            can_target_name_expand(new_target_resolution_details) and
            vim.endswith(new_target_name, target_name) then
          -- vim.notify(vim.inspect({ "3" }))
          extend_target_name = true
        else
          -- collision resolved
          break
        end
      end

      if extend_target_name then
        expand_target_name(target_resolution_details)
        target_name = target_resolution_details.target_name
      end
      if extend_new_target_name then
        expand_target_name(new_target_resolution_details)
        new_target_name = new_target_resolution_details.target_name
      end
    end
  end
  table.insert(collisions[target], new_target_resolution_details)
  -- vim.notify(vim.inspect({ collisions = collisions }))
end

M._add_resolved_target_name_collisions = function(targets_map, project_root)
  if M._collisions[project_root] then
    M._collisions[project_root]['project_location'] = nil
    for target, target_resolution_details in pairs(M._collisions[project_root]) do
      targets_map[target] = nil
      for _, target_resolution_detail in ipairs(target_resolution_details) do
        local target_name = target_resolution_detail.target_name
        if target_resolution_detail['add_filename_extension'] then
          target_name = target_name .. ".go"
        end
        local target_details = target_resolution_detail.target_details
        local target_idx = target_resolution_detail.target_details.idx
        targets_map[target_name] = target_details
        targets_map[menu][items][target_idx] = target_name
        if #target_name > targets_map[menu]['width'] then
          targets_map[menu]['width'] = #target_name
        end
      end
      M._collisions[project_root] = nil
    end
  end
end

-- TODO add description
local function get_project_location(project_root)
  local project_location = project_root:match('^(.*)/.+/*$')
  return project_location
end

M._add_target_to_cache = function(targets_map, target, target_details, project_root)
  local target_name_collision = targets_map[target]

  if not target_name_collision then
    targets_map[target] = target_details
    return
  end

  if not M._collisions[project_root] then
    M._collisions[project_root] = {}
    local project_location = get_project_location(project_root)
    M._collisions[project_root]['project_location'] = project_location
    M._collisions[project_root][target] = {}
    local target_location = targets_map[target][location]
    local target_details = targets_map[target]
    local resolution_string = create_target_name_resolution_string(target_location, project_location)

    table.insert(M._collisions[project_root][target],
      {
        target_name = target,
        target_details = target_details,
        resolution_string = resolution_string,
        capture_pattern = '.*'
      })
  end

  resolve_target_name_collision(target, target_details, project_root)
end



local uv = vim.loop
local write_file = function(path, content)
  uv.fs_open(path, "w", 438, function(open_err, fd)
    assert(not open_err, open_err)
    uv.fs_write(fd, content, -1, function(write_err)
      assert(not write_err, write_err)
      uv.fs_close(fd, function(close_err)
        assert(not close_err, close_err)
      end)
    end)
  end)
end

local read_file = function(path, callback)
  uv.fs_open(path, "r", 438, function(err, fd)
    assert(not err, err)
    uv.fs_fstat(fd, function(err, stat)
      assert(not err, err)
      uv.fs_read(fd, stat.size, 0, function(err, data)
        assert(not err, err)
        uv.fs_close(fd, function(err)
          assert(not err, err)
          callback(data)
        end)
      end)
    end)
  end)
end

function path_exists(file)
  return uv.fs_stat(file) and true or false
end

function load_buildtargets()
  if path_exists(save_location) then
    read_file(save_location, function(data)
      local data = vim.json.decode(data)
      M._cache, M._current_buildtargets = unpack(data)
      -- vim.notify(vim.inspect({ "reading", cache = M._cache, current_buildtarget = M._current_buildtarget }))
      vim.schedule(function()
        require('lualine').refresh()
      end)
    end)
  end
end

function save_buildtargets()
  local data = {
    M._cache, M._current_buildtargets
  }
  local data = vim.json.encode(data)
  write_file(save_location, data)
  -- vim.notify(vim.inspect({ "writing", cache = M._cache, current_buildtarget = M._current_buildtarget }))
end

return M
