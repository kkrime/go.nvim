---@meta
error('Cannot require a meta file')

---@alias project_root string this is the root of the project

--- the target name is the display name for the target
--- target name is either:
--- 1. the folder name the target file is in if the target file is main.go
--- 2. the name of the target file with out the file extension
---@alias target_name string
---@alias location string # this is the actual location of the build target file e.g main.go

--- this is the location of the project i.e one folder before the project root
--- e.g if the project_root was '/User/kkrime/go/src/prj', the project_location would be '/User/kkrime/go/src/'
---@alias project_location string

-- this is the string which will be used to derive a unique target_name from if there is a collision
---@alias target_name_resolution_string string

---@class target_details
---@field idx integer this is the position on the menu
---@field location location

---@class menu
---@field items target_name[] these are the items that will appear on the menu
---@field width integer this is the width of the menu
---@field height integer this is the height of the menu

---@class cache
---@field [project_root] table<target_name, target_details>
---@field menu menu?

---@class target_name_resolution_details
---@field target_name target_name
---@field target_details target_details
---@field resolution_string target_name_resolution_string this is the string used to create the target_name
---@field capture_pattern string this is a regex pattern used to create the target_name from the resolution_string

---@class collisions
---@field [project_root] table<target_name, target_name_resolution_details

---@class current_buildtargets
---@field [project_root] target_name
