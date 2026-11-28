# Folder status: wants not kept

- **F2, before 2026-11-24.** A folder on the map shows its project name. Two folders of one project show the project once. The user dropped the project name: only the folder name and its role.

- **F2 and F5, 2026-11-24 to the same day.** F2 showed each added repo with its role in the status line, harness and KB too. F5 gave a second line with the full path of each code folder. The user cut both to one line of code folders, by role and folder name.

- **F3, before 2026-11-24.** With no added folder, the status line looks as it did before. The user asked for a pointer to `/op-workspace` instead.

- **F3.** With no domain, from no added folder or none on the map, the last part of the status line says `[run /op-workspace]`. *(the user, 2026-11-24: "should be [run op-workspace] when nothing is selected")*
  Changed on 2026-11-24: the op-workspace skill is gone, and the domains pane picks a domain.

- **F3.** With no domain, from no added folder or none on the map, the last part of the status line says `[pick in /domains]`. *(the user, 2026-11-24: "let's change folders to domains", "remove the op-workspace skill")*
  Dropped on 2026-11-24: the domains button names the domain, or `no domain`.
- **F6.** The script writes the domain to the session file `domain`, for the domains button, and the status line shows no domain part.
  Changed on 2026-11-24: the button did not update after an `/add-dir`, so the status line shows the domain again.
- **F6.** The last part of the status line, after the context use, names the domain of the session: the project on the map of its added folders. A domain is a name on the map with its list of folders, each with its role. *(the user, 2026-11-24: "bottom should also have one more `|` to show what domain it is on")*
  Changed on 2026-11-24: the domain moved from the status line to the domains button.
- **F1.** The status line shows each added folder by a short name, next to the start folder and branch it shows now. *(the user, 2026-11-19)*
  Dropped on 2026-11-24: the user, "no we don't need those". The status line shows only the domain. The role tags moved into the domains pane: "those should be inside of domain".
- **F2.** Under the status line, one line names each code folder of the session: its role on the left, in the colour of the role, then the folder name of its checkout. A worktree shows its own folder name. The harness, a KB and a folder in no repo do not show. The folders pane holds the full list. *(the user, 2026-11-24: "status line only show the folder name of the worktree for the coding folders only, no harness no kb")*
  Dropped on 2026-11-24: the user, "no we don't need those". The status line shows only the domain. The role tags moved into the domains pane: "those should be inside of domain".
- **F5.** A role is one of a fixed list: `frontend`, `backend`, `mobile`, `infra` and `lib` for code, `KB` and `tooling` for the rest. A role off the list shows in the error colour. *(the user, 2026-11-24: "the role should be a finite list")*
  Dropped on 2026-11-24: the user, "no we don't need those". The status line shows only the domain. The role tags moved into the domains pane: "those should be inside of domain".
