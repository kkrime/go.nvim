---@meta
error('Cannot require a meta file')

---@alias project_root string this is the root of the project
---@alias target_name string this is the display name for the target
---@alias location string this is the display name for the target

---@class target_details
---@field idx integer this is the position on the menu
---@field location location this is the actual location of the build target file e.g main.go

---@class menu
---@field items target_name[] these are the items that will appear on the menu
---@field width integer this is the width of the menu
---@field height integer this is the height of the menu

---@class cache
---@field [project_root] table<target_name, target_details>
---@field menu menu?

---@class collision_details
---@field target_name target_name
---@field target_details target_details
---@field resolution_string string this is the string used to create the target_name
---@field capture_pattern string this is a regex pattern used to create the target_name from the resolution_string

---@class collisions
---@field [project_root] table<target_name, collision_details>

---@class current_buildtargets
---@field [project_root] target_name
