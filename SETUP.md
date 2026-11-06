# SETUP: slim down OpenCode 2.x

You are an AI coding agent. The user has asked you to apply this repository to their OpenCode
setup. Follow these steps in order. Explain each change before you make it, and stop to ask
whenever this file says **Ask**.

`REPO` below is the directory that contains this file.

Ground rules:

- Back up every file before you change it: copy it to `<file>.bak-<YYYYMMDD>` next to the original.
- Edit only the keys this file names. Never touch `providers`/`provider`, API keys, or anything you were not told to change.
- Run each check yourself and show its output. Don't assume a step worked.
- OpenCode 2 runs a shared background service that keeps the config it loaded. Every `opencode` command
  below uses `--standalone` (a private server that reads the files fresh), so you can check changes without
  restarting the user's service. Never run `opencode service stop`, `restart`, or `reload` yourself; the
  user does that at the end.

## 1. Check the environment

```sh
opencode --version
uname -s
command -v rg python3 git
```

- **OpenCode must be 2.x.** If the major version is 1, stop: tell the user this branch is for OpenCode 2 and
  that OpenCode 1.x support lives on the `main` branch of this repository.
- Find the config directory: `opencode debug paths config` (usually `~/.config/opencode`). Call it `CONFIG` below.
- Read `CONFIG/opencode.json` (or `opencode.jsonc`) and list for the user: the MCP servers (under `mcp.servers`, or
  directly under `mcp` in a V1-style file) and whether each is disabled, the `plugins` (or V1 `plugin`) entries, and
  any existing `permissions`, V1 `permission`/`tools`, `agents`, or V1 `agent` keys.
- Check for `CONFIG/AGENTS.md` and existing agent files in `CONFIG/agents/`, `CONFIG/agent/`, `CONFIG/modes/`, or
  `CONFIG/mode/`. Note the names you find (`build.md`, `plan.md`).
- List the global skills: `ls CONFIG/skills ~/.agents/skills ~/.claude/skills 2>/dev/null`.

## 2. Measure the starting point

```sh
REPO/scripts/measure.sh
```

It prints one number: the tokens the session sends with every request, measured once MCP servers have
connected. Write it down as **BEFORE**, with the model it used (the `model` key in `opencode.json`, or
OpenCode's default). The final measurement must use the same model. It needs two small requests and about
ten seconds. If it fails, check that `opencode run --standalone "hi"` works before you continue.

## 3. Ask what to apply

**Ask** the user which of these to apply. Recommend the first three.

1. **Minimal prompts**: replace the built-in `build` and `plan` prompts, and hide OpenCode's own
   self-management tools and help skills from the model.
2. **Search through `rg`**: turn off the Glob and Grep tools; the agent searches with `rg` in the shell.
3. **Lean AGENTS.md**: review the global instruction file, which is sent with every request.
4. **MCP review**: keep only the MCP servers used daily in the global config, or only the tools of them you use.
5. **Pin the major version**: keep an upgrade from jumping to a future OpenCode 3.

Also ask: **is the Plannotator plugin (`@plannotator/opencode`) installed or wanted?** It decides which plan prompt to use.

## 4. Apply

All rules below go in the top-level `permissions` array of `CONFIG/opencode.json`. If the file has no
`permissions` key, create it; if it has one, append to it and keep the existing rules first. If it still uses the
V1 `permission` object, add a `permissions` array next to it rather than converting it: **ask** the user before
migrating anything else.

### 4.1 Minimal prompts

- If `CONFIG/agents/build.md` or `CONFIG/agents/plan.md` already exists (or the same name in `agent/`, `modes/`,
  `mode/`), show the user and **ask** before replacing it, after backing it up.
- `mkdir -p CONFIG/agents`, then copy:
  - `REPO/agents/build.md` to `CONFIG/agents/build.md`
  - for plan, copy **one** file to `CONFIG/agents/plan.md`: `REPO/agents/plan.plannotator.md` if Plannotator is
    installed or wanted, `REPO/agents/plan.md` otherwise.
- The files replace only the prompt. OpenCode keeps the plan agent's read-only permissions.
- Append these rules. They hide OpenCode's built-in `opencode` Code Mode tools (rename or move sessions, manage
  worktrees, search models, read MCP resources) and its two help skills; together they cost about 1,400 tokens per
  request:

  ```json
  { "action": "opencode_*", "resource": "*", "effect": "deny" },
  { "action": "skill", "resource": "opencode", "effect": "deny" },
  { "action": "skill", "resource": "report", "effect": "deny" }
  ```

  The `worktree_remove` tool stays listed: it is pinned by OpenCode. If the user creates worktrees from the agent,
  **ask** before adding the first rule.

### 4.2 Search through `rg`

- `rg` is required: the build prompt tells the agent to search with it. If `command -v rg` printed nothing,
  install ripgrep first (macOS: `brew install ripgrep`; Debian/Ubuntu: `sudo apt install ripgrep`;
  Fedora: `sudo dnf install ripgrep`) and check `rg --version`. Do not continue with this step until `rg` works.
- Append:

  ```json
  { "action": "glob", "resource": "*", "effect": "deny" },
  { "action": "grep", "resource": "*", "effect": "deny" }
  ```

  A deny on `*` removes the tool from every request. The explore subagent then searches with `rg` or `grep`
  in the shell.
- OpenCode exposes `patch` instead of `edit`/`write` to GPT models; leave that alone.

### 4.3 Lean AGENTS.md

- Measure the file: `wc -c CONFIG/AGENTS.md`. Every character is sent with every request.
- If it doesn't exist, offer `REPO/AGENTS.template.md` as a starting point; the user fills in the tool routing.
- If it exists and is longer than about 4,000 characters, suggest cuts: generic advice the model already follows,
  sections for tools the user no longer has, duplicates of what the prompts above already say. **Ask** before
  removing anything; show a diff.
- OpenCode 2 does not read `~/.claude/CLAUDE.md`; nothing to do there.

### 4.4 MCP review

OpenCode 2 lists MCP tools in a Code Mode catalog in the prompt by default, about 2,000 tokens per server.
A server with `"codemode": false` sends every tool definition instead and costs several times more.

- For each enabled server, measure its cost by disabling it for one run. `OPENCODE_CONFIG_CONTENT` overrides the
  config without editing it; it replaces the whole server entry, so repeat its other fields:

  ```sh
  OPENCODE_CONFIG_CONTENT='{"mcp":{"servers":{"<name>":{<its fields>,"disabled":true}}}}' REPO/scripts/measure.sh
  ```

  The difference from BEFORE is that server's cost. Show the user a table: server, tokens, and whether it has
  `"codemode": false`. A server that costs almost nothing either failed to connect (check
  `opencode mcp list --standalone`) or offers no tools in an empty directory, as per-project indexers do; say which.
- **Ask** for each costly server:
  - **Keep only the tools you use.** Deny the server's tools and allow a few by name. The action is
    `<server>_<tool>`, with characters other than letters, digits, `_`, and `-` replaced by `_`:

    ```json
    { "action": "<server>_*", "resource": "*", "effect": "deny" },
    { "action": "<server>_<tool>", "resource": "*", "effect": "allow" }
    ```

  - **Project-only.** Set `"disabled": true` on it in `CONFIG/opencode.json`. In each project that needs it, create
    or edit `opencode.json` at the project root with the **complete** server entry, without `disabled`. OpenCode 2
    replaces the whole entry, so `{"disabled": false}` alone does not turn it back on.
  - **Remove it.**
- Leave `"codemode": false` alone unless the user asks: some servers need it. Point out what it costs.

### 4.5 Pin the major version

Find out how OpenCode was installed (`command -v opencode`, then check the path), and **ask** before changing it:

- **mise** (path under `.../mise/installs/`): in the config that lists it (`mise ls` shows which), set the version
  to `"2"`. Don't use `mise upgrade --bump`, which skips past the range.
- **npm** (`@opencode/cli`): `npm i -g @opencode/cli@2`.
- **Homebrew** (`anomalyco/tap/opencode-v2`) or the curl installer: no range pin; tell the user to check the major
  version before upgrading.
- If OpenCode updates itself, `"update": "notify"` in `CONFIG/opencode.json` (the default) shows updates instead of
  installing them.

## 5. Verify

Run each and show the output:

```sh
opencode debug agents --standalone   # build "system" starts with "You are a coding assistant",
                                     # plan "system" with "You are a planning assistant"
rg --version
REPO/scripts/measure.sh              # AFTER
```

The `opencode debug agents` output is long JSON; check the fields named in the comments, and that plan's
`permissions` still contain `"action": "edit", "resource": "*", "effect": "deny"`.

Then a smoke test in an empty directory, which also checks that search goes through `rg`:

```sh
d=$(mktemp -d) && git -C "$d" init -q && echo "hello banana" > "$d/note.txt"
(cd "$d" && opencode run --standalone "Which file in this directory contains the word banana? Answer with the file name only.")
```

The answer should be `note.txt`.

## 6. Report

Tell the user:

- **BEFORE → AFTER** tokens and the percentage saved, with the model used.
- Every file changed and its backup.
- How to undo: copy each `.bak-<date>` file back, and delete `CONFIG/agents/build.md` and `CONFIG/agents/plan.md`
  if they didn't exist before.
- Optional plugins: see the README section "Optional plugins".
- **Run `opencode reload`** (or restart OpenCode) to apply the changes: the background service keeps the old
  configuration until then.
