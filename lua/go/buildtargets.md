# buildtargets

Golang projects can have multiple executables or `buildtargets`.

Currently the `:GoBuild` command will either start the build process from a specifc file passed into it as a parameter, or will build from the root directory of the current project.

This presents a problem, as there could be and often are multiple `buildtargets` typicaly locaed in the `cmd/` folder.

Specifying the `buildtarget` each time we run `:GoBuild` is not a very ergonomic way of doing this.

### overview

For this reason, `buildtargets` has been implemented.

Take for example; `https://github.com/zitadel/zitadel`.

Zitadel has the following `buildtargets`:
```
zitadel/     (project root)
├─ main.go                          <--
├─ internal/
│  ├─ api/
│  │  ├─ assets/
│  │  │  ├─ generator/
│  │  │  │  ├─ asset_generator.go   <--
│  ├─ zerrors/
│  │  ├─ generate/
│  │  │  ├─ error_creator.go        <--
│  ├─ protoc/
│  │  ├─ protoc-gen-authoption/
│  │  │  ├─ main.go                 <--
│  ├─ protoc-gen-zitadel/
│  │  ├─ main.go                    <--
```
Given the above, the `buildtargets` are as follows:
<p align="center">
<img width="200" alt="Screenshot 2025-01-15 at 12 24 49" src="https://github.com/user-attachments/assets/2ffd66e8-0308-48a0-b1c6-63901dd5bc15" />
</p>

When you first run `:GoBuild` the menu will pop up and ask you to select a `buildtarget`. 
When a `buildtarget` is selected, it will become the set `buildtarget` for the project and subsequent calls to `:GoBuild` will automatically build that `buildtarget` without prompting the user with the menu.

The selected `buildtarget` will now be on top the list of `buildtargets` in the menu.
This means that the menu will list the `buildtargets` in order of previously selected.

To change the currently set `buildtarget` for a project, run `:GoBuildTargetSelect` and you will be prompted with the menu.

### target names

The name of a `buildtarget` is determined as follows:
- if the file name of the `buildtarget` **is** `main.go` then the folder that `main.go` is in will be used as the `target name`.
- if the file name of the `buildtarget` **is not** `main.go` then the file name without the file extension will be used as the `target name`

#### target name collisions

In cases where two or more targets have the same name e.g:
```
/Users/kkrime/go/src/zitadel/internal/zerrors/generate/error_creator.go
/Users/kkrime/go/src/zitadel/internal/error_creator.go
/Users/kkrime/go/src/zitadel/internal/protoc/internal/error_creator/main.go
```
then the `target names` will expand to include folders in their paths until all the target names are unique and each target is disambiguated.
For the above example, the `target names` would be:
```
generate/error_creator
zitadel/internal/error_creator
protoc/internal/error_creator
```
In very rare instances, the file extension will be included in `target name`, this is when there is no other way to disambiguate two targets using their paths e.g
```
/Users/kkrime/go/src/zitadel/zitadel/main.go
/Users/kkrime/go/src/zitadel/zitadel.go
```
will generate the following `target names`
```
zitadel
zitadel.go
```
note: only the non `mian.go` file name will only ever include its file extension

## refreshing the targets

When you first run `:GoBuild` or `GoBuildTargetSelect` the current project is scanned and all the targets are saved and loaded each time you start nvim.

If you ever add new targets, more or rename any targets, then you need to run a `refresh` in order to add them to the preexisting menu of `buildtargets`. 

To refresh, press `r` while the menu is visible i.e `:GoBuildTargetSelect`, `r`.

note: that between refreshes the order of the refresh targets will stay faithful to the original menu.
- any new targets will be added at the bottom of the menu
- the menu will adapt if any of the previous targets are missing in the refresh and maintain the original order
- if a target is renamed, then it will remain in the place on the menu as it was previously but with its new name
see `lua/tests/go_buildtargets_spec.lua` for more details

### lualine fun
<p float="left">
<img width="500" alt="Screenshot 2025-01-16 at 17 28 43" src="https://github.com/user-attachments/assets/244ead31-50f6-42f6-8345-ec226c87b74b" />
<img width="500" alt="Screenshot 2025-01-16 at 17 32 36" src="https://github.com/user-attachments/assets/6d74da67-7036-482e-baae-27ac5fd0e53f" />

</p>
