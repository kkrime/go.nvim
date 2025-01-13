local save_location = vim.fn.expand("$HOME/.go_buildtargets.json")
local popup = require("plenary.popup")

local get_project_root
local select_buildtarget_callback
local close_menu_keys = { '<Esc>' }

-- map keys
local menu = 'menu'
local items = 'items'
local height = 'height'
local width = 'width'
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
---@return bool # true if buildtargest should be used, false if buildtargets should not be used
function M.use_buildtargets()
  return get_project_root ~= nil
end

--- updates the current_buildtarget
---
---@param buildtarget target_name
---@param project_root project_root
---@return bool # if buildtarget updated to new value, false if current buildtraget already set to buildtarget
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
---
--- @return (target_name|nil) # returns current buildtarget, if there is only one or no buildtarget for a project, will return nil
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

--- gives the target name for a given target location
---
---@param location location
---@return target_name
local function get_target_name(location)
  local target_name = location:match("^.*/(.*)%.go$")
  if target_name ~= "main" then
    return target_name
  end
  target_name = location:match("^.*/(.*)/.*$")
  return target_name
end

--- checks if given file is a target i.e goes it contain 'package main' and 'func main()'
---
---@param file_location string
---@return bool # true if file_location is a target
local function is_file_a_target(file_location)
  local close_buffer = false
  local bufnr = vim.fn.bufnr(file_location)
  if bufnr == -1 then
    vim.api.nvim_command('badd ' .. file_location)
    bufnr = vim.fn.bufnr(file_location)
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

--- searches project to find build targets
--- will update buildtargets in M._cache
---
---@param bufnr integer # bufnr of a buffer with a file from the project open
---@param project_root project_root
---@return (nil|string) # nil if successful, string with error message if error
local function get_project_targets(bufnr, project_root)
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
              local file_location = vim.uri_to_fname(res.location.uri)
              if not vim.startswith(file_location, project_root) then
                goto continue
              end

              if is_file_a_target(file_location) then
                menu_height = menu_height + 1
                local target_name = get_target_name(file_location)
                M._add_target_to_cache(targets, target_name, { idx = menu_height, location = file_location },
                  project_root)
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

--- updates M._cache order when a build target is selected
--- the newly selected build target is set to M._cache[project_root][idx] = 1
--- and will now be on displayed as the first item on the menu
---
---@param selection target_name # the selected build target
---@param project_root project_root
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
end

--- momentarily sets the menu to blank for 20ms
--- then re-populates the the menu to create a 'flash'
--- this gives the user feedback that a request has completed,
--- but there is no change to the menu
---
---@param project_root project_root
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

--- displays and populates menu with build targets from M._cache
--- where the user can select a build target
---
---@param co thread?
local function show_menu(co)
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

  -- capture bufnr of current buffer for get_project_targets()
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
    err = get_project_targets(bufnr_called_from, project_root)
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
end

--- returns the location of the current build target for the current project
---
---@return location location
function M.get_current_buildtarget_location()
  local project_root = get_project_root()
  local current_target = M._current_buildtargets[project_root]
  if current_target then
    local buildtarget_location = M._cache[project_root][current_target][location]
    return buildtarget_location
  end
  return nil
end

--- scans the current project; if only one build target in project
--- and co is not nil (calling from a thread), then return the only
--- build target location to the calling thread, else display the menu
--- and ask user to select the build target
---
---@param co thread?
---@return (nil|string) # nil if successful, string with error message if error
function M.select_buildtarget(co)
  -- TODO check being called from *.go file
  local project_root = get_project_root()
  if not M._cache[project_root] then
    -- project_root hasn't been scanned yet
    local err = get_project_targets(nil, project_root)
    if err then
      vim.notify("error finding build targets: " .. err, vim.log.levels.ERROR)
      return err
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

--- checks if two target are the same based on their location
---
---@return bool
local function match_path(original_location, refresh_location)
  local original_loc = original_location:match('^(.*)/.*$')
  local refresh_loc = refresh_location:match('^(.*)/.*$')
  if original_loc == refresh_loc then
    return true
  end
  return false
end

--- updates the targets in M._cache[project_root] with targets in new_targets
--- if there are targets in new_targets not in M._cache[project_root], then
--- the new targets will be merged into M._cache[project_root]
---
--- note:
--- the updated targets in M._cache[project_root] will be faithful
--- to the original order of M._cache[project_root]
--- this includes targets in which the target has changed its name,
--- but are still the same targets based on their location, their order
--- will be preserved
---
---@param new_targets target_details[] # new targets to be merged into M._cache[project_root]
---@param project_root project_root
M._refresh_project_buildtargets = function(new_targets, project_root)
  local original = M._cache[project_root]

  local updated_current_buildtarget
  local current_buildtarget_location
  local current_buildtarget = M._current_buildtargets[project_root]
  if current_buildtarget then
    current_buildtarget_location = original[current_buildtarget][location]:match('^(.*)/.*$')
  end

  local new_target_not_in_original_marker = nil

  local pre_existing_target_idxs = {}
  local backup_menu_items = original[menu][items]
  original[menu] = nil
  new_targets[menu] = nil
  for _, new_target_details in pairs(new_targets) do
    local refresh_location = new_target_details[location]
    new_target_details[idx] = new_target_not_in_original_marker
    for orig_target_name, original_target_details in pairs(original) do
      local orig_location = original_target_details[location]
      if match_path(orig_location, refresh_location) then
        -- if target exists in original, add to pre_existing_target_idxs
        -- update the idx to preserve the order
        new_target_details[idx] = original_target_details[idx]
        table.insert(pre_existing_target_idxs, new_target_details[idx])
        -- target found in orignal, remote target from original to improve performance of this for loop
        original[orig_target_name] = nil
        break
      end
    end
  end

  -- keep the order of the targets faithful to the orginal
  table.sort(pre_existing_target_idxs)
  local pre_existing_targets_idxs_update_map = {}
  for new_idx = 1, (#pre_existing_target_idxs) do
    local origina_idx = pre_existing_target_idxs[new_idx]
    pre_existing_targets_idxs_update_map[origina_idx] = new_idx
  end

  local menu_height = #pre_existing_target_idxs
  local menu_items = {}
  local menu_width = 0
  for target_name, target_details in pairs(new_targets) do
    local new_target_idx
    local target_idx = target_details[idx]
    if target_idx == new_target_not_in_original_marker then
      -- this is a new target, not found in original, so append to end of targets
      menu_height = menu_height + 1
      new_target_idx = menu_height
    else
      -- target exists in original, so update its idx to preserve/stay faithful to the original order
      new_target_idx = pre_existing_targets_idxs_update_map[target_idx]
      if current_buildtarget then
        local target_buildtarget = target_details[location]:match('^(.*)/.*$')
        if current_buildtarget_location == target_buildtarget then
          updated_current_buildtarget = target_name
          -- current target found, set current_buildtarget to nil to improve performance
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

  update_current_buildtarget(updated_current_buildtarget, project_root)
  new_targets[menu] = { items = menu_items, width = menu_width, height = menu_height }

  M._cache[project_root] = new_targets
  -- TODO think about this...
  if not vim.deep_equal(backup_menu_items, new_targets[menu][items]) then
    save_buildtargets()
  end
end

--- create the target_name_resolution_string from the target_location and the project_location
---
--- @param target_location location
--- @param project_location project_location
--- @return target_name_resolution_string
local function create_target_name_resolution_string(target_location, project_location)
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

--- expands the target name to resolve collisions
---
---@param target_name_resolution_details target_name_resolution_details
local function expand_target_name(target_name_resolution_details)
  local tnrd           = target_name_resolution_details
  local regex_start    = '^.*/('
  local regex_end      = ')$'

  tnrd.capture_pattern = tnrd.capture_pattern .. '/.*'
  local regex          = regex_start .. tnrd.capture_pattern .. regex_end
  local target_name    = tnrd.resolution_string:match(regex)
  tnrd.target_name     = target_name
end

--- determins if a target_name can expand or not
---
---@param target_name_resolution_details target_name_resolution_details
---@return bool # true if target name can expand, false if target name cannot expand
local function can_target_name_expand(target_name_resolution_details)
  local target_resolution_string_length = #target_name_resolution_details.resolution_string - 1
  local target_name_length = #target_name_resolution_details.target_name
  return target_resolution_string_length ~= target_name_length
end

--- resolves target_name collisions
--- will resolve collisions between target_name and update the collision resolution
--- in M._collisions[project_root]
---
--- to add resolved targets in M._collisions[project_root] to M._cache[project_root], M._add_resolved_target_name_collisions() must be called
--- after all colliding targets passed to resolve_target_name_collision()
---
---@param target_name target_name # target name of colliding target
---@param target_details target_details # target details of colliding target
---@param project_root project_root
local function resolve_target_name_collision(target_name, target_details, project_root)
  local collisions                         = M._collisions[project_root]
  local project_location                   = collisions.project_location
  local new_target_resolution_string       = create_target_name_resolution_string(target_details[location],
    project_location)

  local new_target_name_resolution_details = {
    target_name = target_name,
    target_details = target_details,
    resolution_string = new_target_resolution_string,
    capture_pattern = '.*'
  }
  local new_target_name                    = new_target_name_resolution_details.target_name

  for _, target_name_resolution_details in ipairs(collisions[target_name]) do
    local target_name = target_name_resolution_details.target_name

    while true do
      local extend_target_name = false
      local extend_new_target_name = false

      if #target_name == #new_target_name then
        if target_name == new_target_name then
          -- vim.notify(vim.inspect({ "1", new_target_resolution_details, target_resolution_details }))

          if #target_name_resolution_details['resolution_string'] == #new_target_name_resolution_details['resolution_string'] and
              target_name_resolution_details['resolution_string'] == new_target_name_resolution_details['resolution_string'] then
            -- corner case
            local target_location = target_name_resolution_details['target_details'][location]
            if string.sub(target_location, #target_location - 6) ~= "main.go" then
              target_name_resolution_details['add_filename_extension'] = true
            else
              new_target_name_resolution_details['add_filename_extension'] = true
            end
            -- collision resolved
            break
          else
            if can_target_name_expand(target_name_resolution_details) then
              -- vim.notify(vim.inspect({ "can_target_name_expand_", target_resolution_details }))
              extend_target_name = true
            end
            if can_target_name_expand(new_target_name_resolution_details) then
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
        if can_target_name_expand(new_target_name_resolution_details) and
            can_target_name_expand(target_name_resolution_details) and
            vim.endswith(target_name, new_target_name) then
          extend_new_target_name = true
        else
          -- collision resolved
          break
        end
      else -- #new_target_name > #target_name
        if can_target_name_expand(target_name_resolution_details) and
            can_target_name_expand(new_target_name_resolution_details) and
            vim.endswith(new_target_name, target_name) then
          -- vim.notify(vim.inspect({ "3" }))
          extend_target_name = true
        else
          -- collision resolved
          break
        end
      end

      if extend_target_name then
        expand_target_name(target_name_resolution_details)
        target_name = target_name_resolution_details.target_name
      end
      if extend_new_target_name then
        expand_target_name(new_target_name_resolution_details)
        new_target_name = new_target_name_resolution_details.target_name
      end
    end
  end
  table.insert(collisions[target_name], new_target_name_resolution_details)
end

--- this function is a complementary function to resolve_target_name_collision()
---
--- this will add all the resolved colliding targets (resolved using resolve_target_name_collision())
--- in M._collisions[project_root] to M._cache[project_root]
---
---@param targets_map cache
---@param project_root project_root
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
        if #target_name > targets_map[menu][width] then
          targets_map[menu][width] = #target_name
        end
      end
      M._collisions[project_root] = nil
    end
  end
end

--- returns the project location fromt he project_root
--- this is the location of the project i.e one folder before the project root
--- e.g if the project_root was '/User/kkrime/go/src/prj', the project_location would be '/User/kkrime/go/src/'
---
---@param project_root project_root
---@return project_location
local function get_project_location(project_root)
  local project_location = project_root:match('^(.*)/.+/*$')
  return project_location
end

--- adds target to M._cache
--- if a target already exists in M._cache (a collision) then target details will be passed to
--- resolve_target_name_collision()
---
---@param targets_map cache
---@param target_name target_name
---@param target_details target_details
---@param project_root project_root
M._add_target_to_cache = function(targets_map, target_name, target_details, project_root)
  local target_name_collision = targets_map[target_name]

  if not target_name_collision then
    targets_map[target_name] = target_details
    return
  end

  if not M._collisions[project_root] then
    M._collisions[project_root] = {}
    local project_location = get_project_location(project_root)
    M._collisions[project_root]['project_location'] = project_location
    M._collisions[project_root][target_name] = {}
    local target_location = targets_map[target_name][location]
    local target_details = targets_map[target_name]
    local resolution_string = create_target_name_resolution_string(target_location, project_location)

    table.insert(M._collisions[project_root][target_name],
      {
        target_name = target_name,
        target_details = target_details,
        resolution_string = resolution_string,
        capture_pattern = '.*'
      })
  end

  resolve_target_name_collision(target_name, target_details, project_root)
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
end

return M
