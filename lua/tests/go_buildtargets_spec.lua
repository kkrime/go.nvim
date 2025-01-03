-- nvim --headless --noplugin -u lua/tests/minimal.vim -c "PlenaryBustedDirectory lua/tests/go_buildtargets_spec.lua {minimal_init = 'lua/tests/minimal.vim'}"
local eq = assert.are.same
local busted = require('plenary/busted')

local menu = 'menu'
local items = 'items'
local idx = 'idx'
local location = 'location'

local project_root = "/Users/kkrime/go/src/prj"

describe('BuildTarget Refresh:', function()
  local buildtargets = require('go.buildtargets')
  local refresh_project_buildtargets = buildtargets._refresh_project_buildtargets

  it("no change between original and refresh", function()
    buildtargets._cache = {
      [project_root] = {
        ["asset_generator"] = { idx = 4, location = "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
        ["error_creator"] = { idx = 5, location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
        ["protoc-gen-authoption"] = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
        ["protoc-gen-prj"] = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
        ["prj"] = { idx = 3, location = "/Users/kkrime/go/src/prj/main.go" },
        menu = {
          height = 5,
          items = { "protoc-gen-authoption", "protoc-gen-prj", "prj", "asset_generator", "error_creator" },
          width = 21
        },
      }
    }
    local refresh = {
      ["asset_generator"] = { idx = 4, location = "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
      ["error_creator"] = { idx = 5, location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
      ["protoc-gen-authoption"] = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
      ["protoc-gen-prj"] = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
      ["prj"] = { idx = 3, location = "/Users/kkrime/go/src/prj/main.go" },
      menu = {
        height = 5,
        items = { "protoc-gen-authoption", "protoc-gen-prj", "prj", "asset_generator", "error_creator" },
        width = 21
      },
    }
    local expected_result = vim.deepcopy(refresh)

    buildtargets._current_buildtarget[project_root] = 'asset_generator'

    refresh_project_buildtargets(refresh, project_root)

    eq(refresh, expected_result)
    eq(buildtargets._current_buildtarget[project_root], 'asset_generator')
  end)

  it("test case 1; refresh returns same targets, but in with completley different target idxs", function()
    buildtargets._cache = {
      [project_root] = {
        ["protoc-gen-authoption"] = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
        ["protoc-gen-prj"] = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
        ["prj"] = { idx = 3, location = "/Users/kkrime/go/src/prj/main.go" },
        ["asset_generator"] = { idx = 4, location = "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
        ["error_creator"] = { idx = 5, location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
        menu = {
          height = 5,
          items = { "protoc-gen-authoption", "protoc-gen-prj", "prj", "asset_generator", "error_creator" },
          width = 21
        },
      }
    }
    local refresh = { -- target idxs are completley different
      ["protoc-gen-authoption"] = { idx = 5, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
      ["protoc-gen-prj"] = { idx = 4, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
      ["prj"] = { idx = 2, location = "/Users/kkrime/go/src/prj/main.go" },
      ["asset_generator"] = { idx = 3, location = "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
      ["error_creator"] = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
      menu = {
        height = 5,
        items = { "error_creator", "prj", "asset_generator", "protoc-gen-prj", "protoc-gen-authoption" },
        width = 21
      }
    }
    local expected_result = vim.deepcopy(buildtargets._cache[project_root])

    buildtargets._current_buildtarget[project_root] = 'prj'

    refresh_project_buildtargets(refresh, project_root)

    eq(refresh, expected_result)
    eq(buildtargets._current_buildtarget[project_root], 'prj')
  end)

  it("test case 2: refresh returns some more targets than original, with 2 mutal targets in original", function()
    buildtargets._cache = {
      [project_root] = {
        ["error_creator"] = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
        ["prj"] = { idx = 2, location = "/Users/kkrime/go/src/prj/main.go" },
        menu = {
          height = 2,
          items = { "error_creator", "prj" },
          width = 13
        },
      }
    }
    local refresh = { -- 'error_creator' and 'prj' have different target idxs
      ["protoc-gen-authoption"] = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
      ["protoc-gen-prj"] = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
      ["prj"] = { idx = 3, location = "/Users/kkrime/go/src/prj/main.go" },
      ["asset_generator"] = { idx = 4, location = "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
      ["error_creator"] = { idx = 5, location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
      menu = {
        height = 5,
        items = { "protoc-gen-authoption", "protoc-gen-prj", "prj", "asset_generator", "error_creator" },
        width = 21
      }
    }

    buildtargets._current_buildtarget[project_root] = nil

    refresh_project_buildtargets(refresh, project_root)

    eq(buildtargets._current_buildtarget[project_root], nil)

    -- the result should be that refresh contains all the targets, and that the targets that are mutual in
    -- original maintain their priority (in terms of target idxs)

    -- because 'error_creator' was the highest priority in original, it should be the
    -- highest priority in refresh
    local target = 'error_creator'
    local first_target = refresh[target]
    eq(first_target, { idx = 1, location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" })
    eq(refresh[menu][items][1], target)
    refresh[target] = nil

    -- because 'prj' was the second highest priority in original, it should be the
    -- second highest priority in refresh
    target = 'prj'
    local second_target = refresh[target]
    eq(second_target, { idx = 2, location = "/Users/kkrime/go/src/prj/main.go" })
    eq(refresh[menu][items][2], target)
    refresh[target] = nil

    eq(#refresh[menu][items], 5)
    eq(refresh[menu]['width'], 21)

    local items = refresh[menu][items]
    refresh[menu] = nil

    for i = 3, #items do
      target = items[i]
      assert(refresh[target] ~= nil, target .. " should be in refresh")
      eq(refresh[target][idx], i)
      refresh[target] = nil
    end

    eq(refresh, {})
  end)

  it("refresh contains 1 target that is also in original", function()
    -- local original = {
    buildtargets._cache = {
      [project_root] = {
        ["protoc-gen-authoption"] = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
        ["protoc-gen-prj"] = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
        ["prj"] = { idx = 3, location = "/Users/kkrime/go/src/prj/main.go" },
        menu = {
          height = 3,
          items = { "protoc-gen-authoption", "protoc-gen-prj", "prj" },
          width = 21
        },
      },
    }
    local refresh = {
      ["protoc-gen-authoption"] = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
      ["prj"] = { idx = 2, location = "/Users/kkrime/go/src/prj/main.go" },
      menu = {
        height = 2,
        items = { "protoc-gen-authoption", "prj" },
        width = 21
      }
    }
    local expected_result = vim.deepcopy(refresh)

    buildtargets._current_buildtarget[project_root] = "protoc-gen-prj"

    refresh_project_buildtargets(refresh, project_root)

    eq(refresh, expected_result)
    eq(buildtargets._current_buildtarget[project_root], nil)
  end)

  it("refresh contains 2 targets that are also in original but with different idxs", function()
    buildtargets._cache = {
      [project_root] = {
        ["protoc-gen-authoption"] = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
        ["protoc-gen-prj"] = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
        ["prj"] = { idx = 3, location = "/Users/kkrime/go/src/prj/main.go" },
        menu = {
          height = 3,
          items = { "protoc-gen-authoption", "protoc-gen-prj", "prj" },
          width = 21
        },
      },
    }
    local refresh = {
      ["protoc-gen-authoption"] = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
      ["prj"] = { idx = 1, location = "/Users/kkrime/go/src/prj/main.go" },
      menu = {
        height = 2,
        items = { "prj", "protoc-gen-authoption" },
        width = 21
      }
    }
    local expected_result = {
      ["protoc-gen-authoption"] = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
      ["prj"] = { idx = 2, location = "/Users/kkrime/go/src/prj/main.go" },
      menu = {
        height = 2,
        items = { "protoc-gen-authoption", "prj" },
        width = 21
      }
    }

    buildtargets._current_buildtarget[project_root] = 'protoc-gen-prj'

    refresh_project_buildtargets(refresh, project_root)

    eq(refresh, expected_result)
    eq(buildtargets._current_buildtarget[project_root], nil)
  end)

  it("refresh contains 2 targets that are also in original but with different idxs and changed file names", function()
    buildtargets._cache = {
      [project_root] = {
        ["protoc"] = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/protoc.go" },
        ["protoc-gen-prj"] = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
        ["prj"] = { idx = 3, location = "/Users/kkrime/go/src/prj/main.go" },
        menu = {
          height = 3,
          items = { "protoc-gen-authoption", "protoc-gen-prj", "prj" },
          width = 14
        },
      },
    }
    local refresh = {
      ["protoc-gen-authoption"] = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
      ["project"] = { idx = 1, location = "/Users/kkrime/go/src/prj/project.go" },
      menu = {
        height = 2,
        items = { "prj", "protoc-gen-authoption" },
        width = 21
      }
    }
    local expected_result = {
      ["protoc-gen-authoption"] = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
      ["project"] = { idx = 2, location = "/Users/kkrime/go/src/prj/project.go" },
      menu = {
        height = 2,
        items = { "protoc-gen-authoption", "project" },
        width = 21
      }
    }

    buildtargets._current_buildtarget[project_root] = 'protoc'

    refresh_project_buildtargets(refresh, project_root)

    eq(refresh, expected_result)
    eq(buildtargets._current_buildtarget[project_root], "protoc-gen-authoption")
  end)
end)

describe('Resolve Collisions:', function()
  package.loaded['go.buildtargets'] = nil
  local buildtargets = require('go.buildtargets')
  local add_target_to_cache = buildtargets._add_target_to_cache

  it("test case 1 - 3 target name collisions", function()
    local targets_map = {}

    local error_creator1 = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" }
    add_target_to_cache(targets_map, 'error_creator', error_creator1, project_root)

    local expected_target_map = {
      ["error_creator"] = error_creator1
    }
    eq(targets_map, expected_target_map)

    local expected_result = {
      [project_root] = {
        ["error_creator"] = {
          {
            target_name = "generate/error_creator",
            capture_pattern = ".*/.*",
            resolution_string = "/prj/internal/zerrors/generate/error_creator",
            target_details = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
          },
          {
            target_name = "internal/error_creator",
            capture_pattern = ".*/.*",
            resolution_string = "/prj/internal/error_creator",
            target_details = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/error_creator.go" },
          } },
        project_location = "/Users/kkrime/go/src"
      }
    }

    local error_creator2 = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/error_creator.go" }
    add_target_to_cache(targets_map, 'error_creator', error_creator2, project_root)

    eq(buildtargets._collisions, expected_result)

    expected_result = {
      [project_root] = {
        ["error_creator"] = {
          {
            target_name = "generate/error_creator",
            capture_pattern = ".*/.*",
            resolution_string = "/prj/internal/zerrors/generate/error_creator",
            target_details = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
          },
          {
            target_name = "/prj/internal/error_creator",
            capture_pattern = ".*/.*/.*",
            resolution_string = "/prj/internal/error_creator",
            target_details = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/error_creator.go" },
          },
          {
            target_name = "protoc/internal/error_creator",
            capture_pattern = ".*/.*/.*",
            resolution_string = "/prj/internal/protoc/internal/error_creator",
            target_details = { idx = 3, location = "/Users/kkrime/go/src/prj/internal/protoc/internal/error_creator/main.go" },
          } },
        project_location = "/Users/kkrime/go/src"
      }
    }

    local error_creator3 = {
      idx = 3,
      location =
      "/Users/kkrime/go/src/prj/internal/protoc/internal/error_creator/main.go"
    }
    add_target_to_cache(targets_map, 'error_creator', error_creator3, project_root)

    eq(buildtargets._collisions, expected_result)

    local final_results = {
      ["generate/error_creator"] = {
        idx = 1,
        location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go"
      },
      ["/prj/internal/error_creator"] = {
        idx = 2,
        location = "/Users/kkrime/go/src/prj/internal/error_creator.go"
      },
      ["protoc/internal/error_creator"] = {
        idx = 3,
        location = "/Users/kkrime/go/src/prj/internal/protoc/internal/error_creator/main.go"
      },
      menu = {
        height = 3,
        items = { "generate/error_creator", "/prj/internal/error_creator", "protoc/internal/error_creator" },
        width = 29
      },
    }

    targets_map[menu] = {
      height = 3,
      items = { "error_creator", "error_creator", "error_creator" },
      width = 13
    }
    buildtargets._add_resolved_target_name_collisions(targets_map, project_root)

    eq(targets_map, final_results)
    eq(buildtargets._collisions[project_root], nil)
  end)

  it("test case 2 - expanding target name all the way to the project root", function()
    local targets_map = {}

    local error_creator1 = {
      idx = 1,
      location =
      "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator/main.go"
    }
    add_target_to_cache(targets_map, 'error_creator', error_creator1, project_root)

    local expected_target_map = {
      ["error_creator"] = error_creator1
    }
    eq(targets_map, expected_target_map)

    local expected_result = {
      [project_root] = {
        ["error_creator"] = {
          {
            target_name = "generate/error_creator",
            capture_pattern = ".*/.*",
            resolution_string = "/prj/internal/zerrors/generate/error_creator",
            target_details = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator/main.go" },
          },
          {
            target_name = "internal/error_creator",
            capture_pattern = ".*/.*",
            resolution_string = "/prj/internal/error_creator",
            target_details = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/error_creator.go" },
          } },
        project_location = "/Users/kkrime/go/src"
      }
    }

    local error_creator2 = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/error_creator.go" }
    add_target_to_cache(targets_map, 'error_creator', error_creator2, project_root)

    eq(buildtargets._collisions, expected_result)

    expected_result = {
      [project_root] = {
        ["error_creator"] = {
          {
            target_name = "generate/error_creator",
            capture_pattern = ".*/.*",
            resolution_string = "/prj/internal/zerrors/generate/error_creator",
            target_details = { idx = 1, location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator/main.go" },
          },
          {
            -- the target name shoudl expand the way to the project root
            target_name = "/prj/internal/error_creator",
            capture_pattern = ".*/.*/.*",
            resolution_string = "/prj/internal/error_creator",
            target_details = { idx = 2, location = "/Users/kkrime/go/src/prj/internal/error_creator.go" },
          },
          {
            target_name = "prj/internal/error_creator",
            capture_pattern = ".*/.*/.*",
            resolution_string = "/prj/prj/internal/error_creator",
            target_details = { idx = 3, location = "/Users/kkrime/go/src/prj/prj/internal/error_creator.go" },
          } },
        project_location = "/Users/kkrime/go/src"
      }
    }

    local error_creator3 = { idx = 3, location = "/Users/kkrime/go/src/prj/prj/internal/error_creator.go" }
    add_target_to_cache(targets_map, 'error_creator', error_creator3, project_root)

    eq(buildtargets._collisions, expected_result)
    local final_results = {
      ["generate/error_creator"] = {
        idx = 1,
        location = "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator/main.go"
      },
      ["/prj/internal/error_creator"] = {
        idx = 2,
        location = "/Users/kkrime/go/src/prj/internal/error_creator.go"
      },
      ["prj/internal/error_creator"] = {
        idx = 3,
        location = "/Users/kkrime/go/src/prj/prj/internal/error_creator.go"
      },
      menu = {
        height = 3,
        items = { "generate/error_creator", "/prj/internal/error_creator", "prj/internal/error_creator" },
        width = 27
      },
    }

    targets_map[menu] = {
      height = 3,
      items = { "error_creator", "error_creator", "error_creator" },
      width = 13
    }
    buildtargets._add_resolved_target_name_collisions(targets_map, project_root)

    eq(targets_map, final_results)
    eq(buildtargets._collisions[project_root], nil)
  end)

  it("test case 3 - expand colliding target name on project root 1", function()
    local targets_map = {}

    local project_root_target = {
      idx = 1,
      location =
      "/Users/kkrime/go/src/prj/main.go"
    }
    add_target_to_cache(targets_map, 'prj', project_root_target, project_root)

    local expected_target_map = {
      ["prj"] = project_root_target
    }
    eq(targets_map, expected_target_map)

    local expected_result = {
      [project_root] = {
        ["prj"] = {
          {
            target_name = "/prj",
            capture_pattern = ".*",
            resolution_string = "/prj",
            target_details = { idx = 1, location = "/Users/kkrime/go/src/prj/main.go" },
          },
          {
            target_name = "prj",
            capture_pattern = ".*",
            resolution_string = "/prj/prj",
            target_details = { idx = 2, location = "/Users/kkrime/go/src/prj/prj/main.go" },
          } },
        project_location = "/Users/kkrime/go/src"
      }
    }

    local prj = { idx = 2, location = "/Users/kkrime/go/src/prj/prj/main.go" }
    add_target_to_cache(targets_map, 'prj', prj, project_root)

    eq(buildtargets._collisions, expected_result)

    local final_results = {
      ["/prj"] = {
        idx = 1,
        location = "/Users/kkrime/go/src/prj/main.go"
      },
      ["prj"] = {
        idx = 2,
        location = "/Users/kkrime/go/src/prj/prj/main.go"
      },
      menu = {
        height = 2,
        items = { "/prj", "prj" },
        width = 4
      },
    }

    targets_map[menu] = {
      height = 2,
      items = { "prj", "prj" },
      width = 4
    }
    buildtargets._add_resolved_target_name_collisions(targets_map, project_root)

    eq(targets_map, final_results)
    eq(buildtargets._collisions[project_root], nil)
  end)

  it("test case 4 - expand colliding target name on project root 2", function()
    local targets_map = {}

    local project_root_target = {
      idx = 1,
      location =
      "/Users/kkrime/go/src/prj/prj.go"
    }
    add_target_to_cache(targets_map, 'prj', project_root_target, project_root)

    local expected_target_map = {
      ["prj"] = project_root_target
    }
    eq(targets_map, expected_target_map)

    local expected_result = {
      [project_root] = {
        ["prj"] = {
          {
            target_name = "/prj/prj.go",
            capture_pattern = ".*/.*",
            resolution_string = "/prj/prj",
            target_details = {
              idx = 1,
              location = "/Users/kkrime/go/src/prj/prj.go"
            },
          },
          {
            target_name = "/prj/prj",
            capture_pattern = ".*/.*",
            resolution_string = "/prj/prj",
            target_details = {
              idx = 2,
              location = "/Users/kkrime/go/src/prj/prj/main.go"
            },
          },
        },
        project_location = "/Users/kkrime/go/src"
      },
    }

    local prj = { idx = 2, location = "/Users/kkrime/go/src/prj/prj/main.go" }
    -- vim.notify(vim.inspect({ targets_map = targets_map }))
    add_target_to_cache(targets_map, 'prj', prj, project_root)
    -- vim.notify(vim.inspect({ expected_result = expected_result }))
    eq(buildtargets._collisions, expected_result)

    local final_results = {
      ["/prj/prj.go"] = {
        idx = 1,
        location = "/Users/kkrime/go/src/prj/prj.go"
      },
      ["/prj/prj"] = {
        idx = 2,
        location = "/Users/kkrime/go/src/prj/prj/main.go"
      },
      menu = {
        height = 2,
        items = { "/prj/prj.go", "/prj/prj" },
        width = 11
      },
    }

    targets_map[menu] = {
      height = 2,
      items = { "prj", "prj" },
      width = 4
    }
    buildtargets._add_resolved_target_name_collisions(targets_map, project_root)

    eq(targets_map, final_results)
    eq(buildtargets._collisions[project_root], nil)
  end)

  -- TODO
  -- this in reverse
  it("test case 5 - expand colliding target name on project root 3", function()
    local targets_map = {}

    local project_root_target = {
      idx = 1,
      location =
      "/Users/kkrime/go/src/prj/prj/main.go"
    }
    add_target_to_cache(targets_map, 'prj', project_root_target, project_root)

    local expected_target_map = {
      ["prj"] = project_root_target
    }
    eq(targets_map, expected_target_map)

    local expected_result = {
      [project_root] = {
        ["prj"] = {
          {
            target_name = "/prj/prj",
            capture_pattern = ".*/.*",
            resolution_string = "/prj/prj",
            target_details = {
              idx = 1,
              location = "/Users/kkrime/go/src/prj/prj/main.go"
            },
          },
          {
            target_name = "/prj/prj.go",
            capture_pattern = ".*/.*",
            resolution_string = "/prj/prj",
            target_details = {
              idx = 2,
              location = "/Users/kkrime/go/src/prj/prj.go"
            },
          },
        },
        project_location = "/Users/kkrime/go/src"
      },
    }

    local prj = { idx = 2, location = "/Users/kkrime/go/src/prj/prj.go" }
    add_target_to_cache(targets_map, 'prj', prj, project_root)
    eq(buildtargets._collisions, expected_result)

    local final_results = {
      ["/prj/prj"] = {
        idx = 1,
        location = "/Users/kkrime/go/src/prj/prj/main.go"
      },
      ["/prj/prj.go"] = {
        idx = 2,
        location = "/Users/kkrime/go/src/prj/prj.go"
      },
      menu = {
        height = 2,
        items = { "/prj/prj", "/prj/prj.go" },
        width = 11
      }
    }

    targets_map[menu] = {
      height = 2,
      items = { "prj", "prj" },
      width = 3
    }
    buildtargets._add_resolved_target_name_collisions(targets_map, project_root)

    eq(targets_map, final_results)
    eq(buildtargets._collisions[project_root], nil)
  end)

  it("test case 6 - expand colliding target name on project root 4", function()
    local targets_map = {}

    local project_root_target = {
      idx = 1,
      location =
      "/Users/kkrime/go/src/prj/prj/main.go"
    }
    add_target_to_cache(targets_map, 'prj', project_root_target, project_root)

    local expected_target_map = {
      ["prj"] = project_root_target
    }
    eq(targets_map, expected_target_map)

    local expected_result = {
      [project_root] = {
        ["prj"] = {
          {
            target_name = "prj",
            capture_pattern = ".*",
            resolution_string = "/prj/prj",
            target_details = {
              idx = 1,
              location = "/Users/kkrime/go/src/prj/prj/main.go"
            },
          },
          {
            target_name = "/prj",
            capture_pattern = ".*",
            resolution_string = "/prj",
            target_details = {
              idx = 2,
              location = "/Users/kkrime/go/src/prj/main.go"
            },
          }
        },
        project_location = "/Users/kkrime/go/src"
      },
    }

    local prj = { idx = 2, location = "/Users/kkrime/go/src/prj/main.go" }
    add_target_to_cache(targets_map, 'prj', prj, project_root)
    -- vim.notify(vim.inspect({ expected_result = expected_result }))
    -- vim.notify(vim.inspect({ _collisions = buildtargets._collisions }))
    eq(buildtargets._collisions, expected_result)

    local final_results = {
      ["/prj"] = {
        idx = 2,
        location = "/Users/kkrime/go/src/prj/main.go"
      },
      ["prj"] = {
        idx = 1,
        location = "/Users/kkrime/go/src/prj/prj/main.go"
      },
      menu = {
        height = 2,
        items = { "prj", "/prj" },
        width = 4
      },
    }

    targets_map[menu] = {
      height = 2,
      items = { "prj", "prj" },
      width = 4
    }
    buildtargets._add_resolved_target_name_collisions(targets_map, project_root)
    -- vim.notify(vim.inspect({ targets_map = targets_map }))

    eq(targets_map, final_results)
    eq(buildtargets._collisions[project_root], nil)
  end)
  -- TODO
  -- /Users/kkrime/go/src/prj/internal/api/assets/generator.go
  -- /Users/kkrime/go/src/prj/internal/api/assets/generator/main.go
  -- /Users/kkrime/go/src/prj/api/assets/generator.go
  -- /Users/kkrime/go/src/prj/api/assets/generator/main.go
end)
