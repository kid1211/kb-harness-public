```graph
begin asked
end folders project fallback listed
fail no_map
external map_page caller
asked: A caller asks for the folders of a project, the project of a path, or the projects.
asked.run: caller
read: The script reads the table of the map page, one row per folder.
read.run: map_page
map?: Does the map page exist and hold a table?
kind?: Which look-up?
folders: The script prints each folder of the project, one path per line.
project: The script prints the project of the folder that holds the path.
fallback: The path is on no row, so the script prints the folder name of the path.
listed: The script prints each project with its folders, or the projects only for an unknown name.
no_map: The script says the map is missing and prints nothing else.
known?: Is the project, or a folder above the path, on the map?
map_page: The map page claude-research/projects.md in the personal KB
caller: Claude, the status line, or the project start
asked -> read
read -> map?
map? -> kind? [yes], no_map [no]
kind? -> known? [folders or project], listed [list]
known? -> folders [project known], project [folder known], fallback [folder unknown], listed [project unknown]
```
