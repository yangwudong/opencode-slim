# SETUP: slim down OpenCode 1.x

You are an AI coding agent. The user has asked you to apply this repository to their OpenCode
setup. Follow these steps in order. Explain each change before you make it, and stop to ask
whenever this file says **Ask**.

`REPO` below is the directory that contains this file.

Ground rules:

- Back up every file before you change it: copy it to `<file>.bak-<YYYYMMDD>` next to the original.
- Edit only the keys this file names. Never touch `provider`, API keys, or anything you were not told to change.
- Run each check yourself and show its output. Don't assume a step worked.

## 1. Check the environment

```sh
opencode --version
uname -s
command -v rg python3 git
```

- **OpenCode must be 1.x.** If the major version is 2 or higher, stop: tell the user this branch is for
  OpenCode 1.x and that OpenCode 2 support lives on the `opencode-2` branch of this repository.
- Find the config directory: `opencode debug paths` prints it on the `config` line (usually
  `~/.config/opencode`). Call it `CONFIG` below.
- Read `CONFIG/opencode.json` (or `opencode.jsonc`) and list for the user: the `mcp` servers and whether each
  is enabled, the `plugin` entries, and any existing `tools`, `permission`, or `agent` keys.
- Check for `CONFIG/AGENTS.md`, `~/.claude/CLAUDE.md`, and existing agent files in `CONFIG/agents/`,
  `CONFIG/agent/`, `CONFIG/modes/`, or `CONFIG/mode/`. Note the names you find (`build.md`, `plan.md`).
- List the global skills: `ls ~/.agents/skills ~/.claude/skills CONFIG/skills 2>/dev/null`.

## 2. Measure the starting point

```sh
REPO/scripts/measure.sh
```

It prints one number: the tokens of the first request. Write it down as **BEFORE**, with the model
it used (the `model` key in `opencode.json`, or OpenCode's default). The final measurement must
use the same model. If it fails, check that `opencode run "hi"` works before you continue.

## 3. Ask what to apply

**Ask** the user which of these to apply. Recommend the first three.

1. **Minimal prompts**: replace the built-in `build` and `plan` prompts.
2. **Search through `rg`**: turn off the Glob and Grep tools; the agent searches with `rg` in bash.
3. **Lean AGENTS.md**: review the global instruction file, which is sent with every request.
4. **MCP review**: keep only the MCP servers used daily in the global config.
5. **Keep OpenCode on 1.x**: pin the version so an upgrade can't jump to OpenCode 2.

Also ask: **is the Plannotator plugin (`@plannotator/opencode`) installed or wanted?** It decides which plan prompt to use.

## 4. Apply

### 4.1 Minimal prompts

- If `CONFIG/agents/build.md` or `CONFIG/agents/plan.md` already exists (or the same name in `agent/`, `modes/`,
  `mode/`), show the user and **ask** before replacing it, after backing it up.
- `mkdir -p CONFIG/agents`, then copy:
  - `REPO/agents/build.md` to `CONFIG/agents/build.md`
  - for plan, copy **one** file to `CONFIG/agents/plan.md`: `REPO/agents/plan.plannotator.md` if Plannotator is
    installed or wanted, `REPO/agents/plan.md` otherwise.
- The files replace only the prompt. OpenCode keeps the plan agent's read-only permissions.

### 4.2 Search through `rg`

- `rg` is required: the build prompt tells the agent to search with it. If `command -v rg` printed nothing,
  install ripgrep first (macOS: `brew install ripgrep`; Debian/Ubuntu: `sudo apt install ripgrep`;
  Fedora: `sudo dnf install ripgrep`; Windows: `winget install BurntSushi.ripgrep.MSVC`) and check
  `rg --version`. Do not continue with this step until `rg` works.
- Add to `CONFIG/opencode.json`, merging with an existing `permission` object instead of replacing it:

  ```json
  "permission": { "glob": "deny", "grep": "deny" }
  ```

  If the file still uses the deprecated `tools` key, add `"glob": false, "grep": false` there instead.
  Both remove the two tools from every request.

### 4.3 Lean AGENTS.md

- Measure the file: `wc -c CONFIG/AGENTS.md`. Every character is sent with every request.
- If it doesn't exist, offer `REPO/AGENTS.template.md` as a starting point; the user fills in the tool routing.
- If it exists and is longer than about 4,000 characters, suggest cuts: generic advice the model already follows,
  sections for tools the user no longer has, duplicates of what the prompts above already say. **Ask** before
  removing anything; show a diff.
- `~/.claude/CLAUDE.md` is also loaded when present. If the user doesn't want it in OpenCode, set
  `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1` in their shell profile.

### 4.4 MCP review

Every enabled MCP server sends all of its tool definitions with every request, often thousands of tokens each.

- For each enabled server, measure its cost by disabling it for one run; `OPENCODE_CONFIG_CONTENT` overrides the
  config without editing it:

  ```sh
  OPENCODE_CONFIG_CONTENT='{"mcp":{"<name>":{"enabled":false}}}' REPO/scripts/measure.sh
  ```

  The difference from BEFORE is that server's cost. Show the user a table: server, tokens. A server that
  costs almost nothing either failed to connect (check `opencode mcp list`) or offers no tools in an empty
  directory, as per-project indexers do; say which.
- **Ask** for each costly server: keep it global, make it project-only, or remove it.
- Project-only: set `"enabled": false` for it in `CONFIG/opencode.json`, and in each project that needs it create
  or edit `opencode.json` at the project root with `{"mcp": {"<name>": {"enabled": true}}}`.

### 4.5 Keep OpenCode on 1.x

OpenCode 2 changes the plugin API and the TUI config, and plugins written for 1.x don't run on it.
Find out how OpenCode was installed (`command -v opencode`, then check the path), and **ask** before changing it:

- **mise** (path under `.../mise/installs/`): in the config that lists it (`mise ls opencode` shows which),
  set the version to `"1"`, for example `"github:anomalyco/opencode" = "1"`. Don't use `mise upgrade --bump`,
  which skips past the range.
- **Homebrew**: `brew info opencode` shows the version. The core formula already ships OpenCode 2; the
  `anomalyco/tap/opencode` formula stays on 1.x.
- **npm** (`opencode-ai`): install with `npm i -g opencode-ai@1`.
- **curl installer** (`~/.opencode/bin`): it installs only 1.x. Run `opencode upgrade` without `--major`.

## 5. Verify

Run each and show the output:

```sh
opencode debug agent build    # "prompt" starts with "You are a coding assistant"; "tools" has "glob": false, "grep": false
opencode debug agent plan     # "prompt" starts with "You are a planning assistant"
rg --version
REPO/scripts/measure.sh       # AFTER
```

The `opencode debug agent` output is long; check the fields named in the comments. For plan, also
check that `"permission"` still has the rule `"permission": "edit", "pattern": "*", "action": "deny"`
(its `"tools"` map shows `"edit": true` either way; the permission rule is what blocks edits).

Then a smoke test in an empty directory, which also checks that search goes through `rg`:

```sh
d=$(mktemp -d) && git -C "$d" init -q && echo "hello banana" > "$d/note.txt"
(cd "$d" && opencode run "Which file in this directory contains the word banana? Answer with the file name only.")
```

The answer should be `note.txt`.

## 6. Report

Tell the user:

- **BEFORE → AFTER** tokens and the percentage saved, with the model used.
- Every file changed and its backup.
- How to undo: copy each `.bak-<date>` file back, and delete `CONFIG/agents/build.md` and `CONFIG/agents/plan.md`
  if they didn't exist before.
- Optional plugins: see the README section "Optional plugins".
- Restart OpenCode: running sessions keep the old setup.
