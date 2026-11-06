# opencode-slim

**The OpenCode TUI, as lightweight as Pi.**

**English** · [简体中文](README.zh-CN.md)

> This branch is for **OpenCode 2.x**. For OpenCode 1.x, use the [`main`](https://github.com/yangwudong/opencode-slim/tree/main) branch.

## Why

OpenCode has the better TUI, but every session starts heavy. A long, generic system prompt and
a long list of built-in tools are sent with every request before you type a word, and most of
those tools never get called. [Pi](https://pi.dev) starts light, but its TUI and controls are
hard to live with.

This repository keeps OpenCode's TUI and trims the rest toward Pi's weight. It changes
configuration only: no fork, no patched binary, and every change is undone by restoring a file.

## Results

OpenCode 2 already starts lighter than OpenCode 1, and this branch takes it down by another
third. Measured on a clean OpenCode 2.2.5 install with [`scripts/measure.sh`](scripts/measure.sh),
build agent:

| Model | Stock | Slim | Stock + 1 MCP server | Slim + 1 MCP server |
|---|---|---|---|---|
| GLM-5.3-Flash | 5,228 | **3,547** (−32%) | 7,467 | 5,949 |
| Claude Haiku 5.5 | 8,036 | **5,378** (−33%) | 11,613 | 9,374 |
| GPT-6.1 Sol | 4,606 | **2,797** (−39%) | 6,886 | 5,239 |
| Kimi K3 | 6,428 | **3,358** (−48%) | 8,691 | 5,818 |

The MCP server is Atlassian's, with 32 tools. OpenCode picks a different default prompt per model
family, which is why stock numbers differ; the slim prompt is the same for all of them. For what
the same changes did on OpenCode 1.x, measured with [Magpie](https://github.com/yetone/magpie),
see the [`main`](https://github.com/yangwudong/opencode-slim/tree/main#results) branch.

## What changes

| Change | Effect | Needs |
|---|---|---|
| Minimal `build` and `plan` prompts in `~/.config/opencode/agents/` | Replace OpenCode's default prompt with about 25 lines | — |
| Hide the `opencode` Code Mode tools and the built-in help skills | About 1,300 fewer tokens: tools to rename sessions, manage worktrees, and search models | — |
| Glob and Grep tools off | Two fewer tool definitions per request; the agent searches with `rg` in the shell | [ripgrep](https://github.com/BurntSushi/ripgrep) |
| Lean global `AGENTS.md` | Sent with every request; aim for under 4,000 characters | — |
| MCP review | Keep only the servers, or the tools, you use daily | — |
| Pin the major version | An upgrade can't jump to a future OpenCode 3 | — |

All of it is permission rules and two Markdown files. The plan agent keeps OpenCode's read-only
permissions; only its prompt changes.

### MCP on OpenCode 2

OpenCode 2 lists MCP tools in a compact Code Mode catalog by default, about 2,000 tokens for a
32-tool server. Setting `"codemode": false` sends every tool definition instead: the same server
then costs about 12,800. To trim further, deny the server's tools and allow the few you use:

```json
"permissions": [
  { "action": "Atlassian_*", "resource": "*", "effect": "deny" },
  { "action": "Atlassian_getJiraIssue", "resource": "*", "effect": "allow" }
]
```

Allowing 3 of the 32 Atlassian tools brought its cost from about 2,400 tokens to about 1,100.

## Install

Clone the repository and give your agent the runbook:

```sh
git clone -b opencode-2 https://github.com/yangwudong/opencode-slim
```

Then, in OpenCode (or any coding agent):

```text
Read opencode-slim/SETUP.md and follow it.
```

The agent checks your version, measures your setup, asks which changes to apply, backs up every
file it touches, verifies the result, and reports the tokens saved. To do it by hand, follow
[SETUP.md](SETUP.md) yourself. Run `opencode reload` afterwards: the background service keeps the
configuration it loaded.

## Measure your setup

```sh
scripts/measure.sh                         # default model and agent
scripts/measure.sh -m provider/model -a plan
```

It sends one tiny prompt from an empty temporary repository, on a private server so your
background service is untouched, and prints the tokens sent with each request once MCP servers
have connected. Compare runs with the same model only, since tokenizers differ. To see what an MCP
server costs, measure with it disabled; repeat its other fields, since the override replaces the
whole entry:

```sh
OPENCODE_CONFIG_CONTENT='{"mcp":{"servers":{"<name>":{<its fields>,"disabled":true}}}}' scripts/measure.sh
```

## Optional plugins

None of these is required.

| Plugin | What it does | OpenCode 2 |
|---|---|---|
| [opencode-tps-meter](https://github.com/yangwudong/opencode-tps-meter) | Shows the model's output speed (tokens per second) in the TUI. | Yes, in `cli.json` |
| [opencode-bark-notify](https://github.com/yangwudong/opencode-bark-notify) | Pushes the agent's replies, questions, and permission requests to your iPhone through the Bark app. | Not yet |
| [opencode-quota](https://github.com/slkiser/opencode-quota) | Quota and token usage for Copilot, Z.ai, Kimi, OpenCode Go, and more, without polluting the context window. | Yes, 5.x and later |
| [Plannotator](https://github.com/backnotprop/plannotator) | Review and annotate the plan agent's plans before implementation. SETUP.md installs a plan prompt that submits to it. | Yes |
| [cc-safety-net](https://github.com/kenryu42/cc-safety-net) | Blocks destructive shell commands such as `rm -rf` outside the project or `git push --force`. | Yes |
| [opencode-notifier](https://github.com/mohak34/opencode-notifier) | Desktop notifications and sounds when the agent finishes or needs permission. OpenCode 2 has built-in notifications; see its README to avoid duplicates. | Yes |

On OpenCode 2, plugins go under `plugins` in `opencode.json`, and TUI-only plugins such as
tps-meter go in `cli.json`. Each plugin's README has the details.

## Measuring with Magpie

[Magpie](https://github.com/yetone/magpie) routes every coding agent's model through one local
gateway, and its context page shows what each agent's prompts are made of. Its "Lean start"
score compares what every request starts with to the model's context window: full marks at 5% or
less, none at 30%.

## License

[MIT](LICENSE)
