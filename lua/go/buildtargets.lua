local buildtargets = {}
local cache = {}
local current_buildtarget = {}
local get_project_root = require("project_nvim.project").get_project_root
local save_path = vim.fn.expand("$HOME/.go_build.json")

local menu = 'menu'
local items = 'items'

function buildtargets.get_current_buildtarget()
  local project_root = get_project_root()
  local current_target = current_buildtarget[project_root]
  if current_target then
    if #cache[project_root][menu][items] > 1 then
      return current_target
    end
  end
  return nil
end

local ShowMenu = function(opts, projs, co)
  local popup = require("plenary.popup")
  local height = opts.height
  local width = opts.width
  local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }

  local selection
  local winnr = popup.create(opts.items, {
    title = "Select Go Project",
    -- highlight = "Cursor",
    line = math.floor(((vim.o.lines - height) / 5.0) - 1),
    col = math.floor((vim.o.columns - width) / 2),
    minwidth = 30,
    minheight = 13,
    borderchars = borderchars,
    callback = function(_, sel)
      selection = projs[sel][2]
      local project_root = get_project_root()
      update_project_map(project_root, sel)
      -- require('lualine').refresh()
    end
  })

  vim.api.nvim_win_set_option(winnr, 'cursorline', true)
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", ":q<CR>", { silent = false })

  -- disable insert mode
  vim.cmd("set nomodifiable")

  -- disable the cursor
  -- https://github.com/goolord/alpha-nvim/discussions/75
  local hl = vim.api.nvim_get_hl_by_name('Cursor', true)
  hl.blend = 100
  vim.api.nvim_set_hl(0, 'Cursor', hl)
  vim.opt.guicursor:append('a:Cursor/lCursor')

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(winnr),
    callback = function()
      coroutine.resume(co, selection)
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = bufnr,
    callback = function()
      vim.cmd("set nomodifiable")
      hl.blend = 100
      vim.api.nvim_set_hl(0, 'Cursor', hl)
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    callback = function()
      vim.cmd("set modifiable")
      hl.blend = 0
      vim.api.nvim_set_hl(0, 'Cursor', hl)
    end,
  })
end

function buildtargets.get_current_buildtarget_location()
  -- local project_root = get_project_root()
  -- local current_target = current_buildtarget[project_root]
  -- if current_target then
  --   local buildtarget_location = cache[project_root][current_target][2]
  --   return buildtarget_location
  -- end
  return nil
end

function buildtargets.select_buildtarget(co)
  local project_root = get_project_root()
  -- project_root hasn't been scanned yet
  if not cache[project_root] then
    buildtargets.scan_project(project_root)
  end
  ShowMenu(cache[project_root][menu], cache[project_root], co)
end

function update_project_map(project_root, selection)
  current_buildtarget[project_root] = selection
  local selection_idx = cache[project_root][selection][1]
  if selection_idx == 1 then
    return
  end

  local selection_backup = cache[project_root][selection]
  cache[project_root][selection] = nil
  selection_backup[1] = 1
  cache[project_root][menu] = nil

  local items = {}
  local width = #selection
  local height = 1

  for project, proj_details in pairs(cache[project_root]) do
    local proj_idx = proj_details[1]
    if proj_idx < selection_idx or proj_idx == 2 then
      proj_idx = proj_idx + 1
      proj_details[1] = proj_idx
    end
    items[proj_idx] = project
    height = height + 1
    if #project > width then
      width = #project
    end
  end
  cache[project_root][selection] = selection_backup
  items[1] = selection

  cache[project_root][menu] = { items = items, width = width, height = height }
end

function buildtargets.scan_project(project_root)
  local ms = require('vim.lsp.protocol').Methods
  local method = ms.workspace_symbol
  local result = vim.lsp.buf_request_sync(0, method, { query = "main" })

  local lines = {}
  local width = 0
  local height = 0
  cache[project_root] = {}
  if result then
    for _, ress in pairs(result) do
      for _, resss in pairs(ress) do
        for _, res in pairs(resss) do
          if res.name == "main" then
            -- filter functions only (vlaue 12)
            if res.kind == 12 then
              local filelocation = vim.uri_to_fname(res.location.uri)

              if not vim.startswith(filelocation, project_root) then
                goto continue
              end

              -- TODO check if filelocation already opened
              -- open file
              vim.api.nvim_command('badd ' .. filelocation)

              local bufnr = vim.fn.bufnr(filelocation)

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

              if ts_query_match == 3 then
                local projectname = getprojectname(filelocation)
                height = height + 1
                cache[project_root][projectname] = { height, filelocation }
                if #projectname > width then
                  width = #projectname
                end
                lines[height] = projectname
              end
            end
          end
          ::continue::
        end
      end
    end
  end
  if height > 0 then
    cache[project_root][menu] = { items = lines, width = width, height = height }
    -- current_buildtarget[project_root] = lines[1]
  else
    -- error message unable to find main package with main function
  end
end

function getprojectname(location)
  local filename = location:match("^.*/(.*)%.go$")
  if filename ~= "main" then
    return filename
  end

  local name = location:match("^.*/(.*)/.*$")
  return name
end

function writebuildsfile(data)
  local data = vim.json.encode(data)
  if cache ~= data then
    require("bookmarks.util").write_file(save_path, data)
  end
end

function readbuildsfile()
  require("bookmarks.util").read_file(save_path, function(data)
    cache = vim.json.decode(data)
  end)
end

return buildtargets
