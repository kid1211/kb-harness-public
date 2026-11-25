# Local e2e: designs not chosen

- **A test plan only, in `tests/e2e/`.** The other e2e files are plans that nothing runs. The user asked for a check to run while building, so this level has a script too.
- **Stub `claude`, as `test-project-start.sh` does.** A stub shows the arguments, not what Claude Code loads. Skill and instructions loading is the thing to test, so the e2e needs real sessions.
- **Test folders in a temp folder.** The user asked for them next to the harness, so he can open them. `MF_FIXTURE` still moves them.
