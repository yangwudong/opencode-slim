# opencode-slim

**OpenCode 的 TUI，Pi 一样的轻量。**

[English](README.md) · **简体中文**

> 本分支适用于 **OpenCode 2.x**。OpenCode 1.x 请用 [`main`](https://github.com/yangwudong/opencode-slim/tree/main) 分支。

## 为什么

OpenCode 的 TUI 更好用，但每个会话起步都很重：你还没输入一个字，冗长通用的系统提示词和一长串内置工具
就随每个请求一起发出去了，而这些工具大多从来不会被调用。[Pi](https://pi.dev) 起步很轻，但它的 TUI
和操作方式让人难以忍受。

这个仓库保留 OpenCode 的 TUI，把其余部分裁剪到接近 Pi 的分量。它只改配置：不 fork、不改二进制，
每项改动都能通过还原一个文件撤销。

## 效果

OpenCode 2 本身起步就比 OpenCode 1 轻，本分支在此基础上再减掉约三分之一。在全新安装的 OpenCode 2.2.5
上用 [`scripts/measure.sh`](scripts/measure.sh) 测量（build agent）：

| 模型 | 原版 | 精简 | 原版 + 1 个 MCP | 精简 + 1 个 MCP |
|---|---|---|---|---|
| GLM-5.3-Flash | 5,228 | **3,547**（−32%） | 7,467 | 5,949 |
| Claude Haiku 5.5 | 8,036 | **5,378**（−33%） | 11,613 | 9,374 |
| GPT-6.1 Sol | 4,606 | **2,797**（−39%） | 6,886 | 5,239 |
| Kimi K3 | 6,428 | **3,358**（−48%） | 8,691 | 5,818 |

表中的 MCP 是 Atlassian 的服务器，有 32 个工具。OpenCode 会按模型家族选用不同的默认提示词，所以各模型
的原版数字不同；精简版对所有模型用的是同一个提示词。同样的改动在 OpenCode 1.x 上的效果（用
[Magpie](https://github.com/yetone/magpie) 测量），见 [`main`](https://github.com/yangwudong/opencode-slim/tree/main#效果) 分支。

## 改了什么

| 改动 | 效果 | 依赖 |
|---|---|---|
| 精简的 `build` 和 `plan` 提示词，放在 `~/.config/opencode/agents/` | 用约 25 行替换 OpenCode 的默认提示词 | — |
| 隐藏 `opencode` 这组 Code Mode 工具和两个内置帮助 skill | 少约 1,300 tokens：重命名会话、管理 worktree、搜索模型等工具 | — |
| 关闭 Glob 和 Grep 工具 | 每个请求少两个工具定义；agent 改用 shell 里的 `rg` 搜索 | [ripgrep](https://github.com/BurntSushi/ripgrep) |
| 精简全局 `AGENTS.md` | 它随每个请求发送；建议控制在 4,000 字符以内 | — |
| 精简 MCP | 只保留每天都用的服务器，或者只保留用得到的工具 | — |
| 固定大版本 | 升级不会跳到将来的 OpenCode 3 | — |

全部改动就是几条权限规则加两个 Markdown 文件。plan agent 保留 OpenCode 的只读权限，只替换提示词。

### OpenCode 2 上的 MCP

OpenCode 2 默认把 MCP 工具放进一个精简的 Code Mode 目录里，一个有 32 个工具的服务器约占 2,000 tokens。
如果设置 `"codemode": false`，就会改为发送全部工具定义，同一个服务器要占约 12,800。想再省一些，可以先禁止
这个服务器的全部工具，再单独放行要用的几个：

```json
"permissions": [
  { "action": "Atlassian_*", "resource": "*", "effect": "deny" },
  { "action": "Atlassian_getJiraIssue", "resource": "*", "effect": "allow" }
]
```

只放行 Atlassian 32 个工具中的 3 个后，它的开销从约 2,400 tokens 降到约 1,100。

## 安装

clone 仓库，把执行手册交给你的 agent：

```sh
git clone -b opencode-2 https://github.com/yangwudong/opencode-slim
```

然后在 OpenCode（或任意 coding agent）里说：

```text
Read opencode-slim/SETUP.md and follow it.
```

agent 会检查版本、测量你当前的配置、询问要应用哪些改动、备份每个要改的文件、验证结果，并报告省下的
tokens。想手动操作的话，照着 [SETUP.md](SETUP.md) 一步步做即可。改完后运行 `opencode reload`：后台服务
会一直沿用它已经加载的配置。

## 测量你的配置

```sh
scripts/measure.sh                         # 默认模型和 agent
scripts/measure.sh -m provider/model -a plan
```

它在一个空的临时仓库里发一句很短的提示，用的是私有服务器，不会碰你的后台服务；等 MCP 服务器连上后，输出
每个请求固定发送的 tokens。只有同一个模型的结果之间才能比较，因为不同模型的分词方式不同。想知道某个 MCP
服务器占多少，就在关掉它的情况下再测一次；这个覆盖会替换整个服务器条目，所以要把它的其他字段一起写上：

```sh
OPENCODE_CONFIG_CONTENT='{"mcp":{"servers":{"<name>":{<its fields>,"disabled":true}}}}' scripts/measure.sh
```

## 可选插件

以下插件都不是必需的。

| 插件 | 作用 | OpenCode 2 |
|---|---|---|
| [opencode-tps-meter](https://github.com/yangwudong/opencode-tps-meter) | 在 TUI 里显示模型的输出速度（tokens/秒）。 | 支持，写在 `cli.json` 里 |
| [opencode-bark-notify](https://github.com/yangwudong/opencode-bark-notify) | 通过 Bark 把 agent 的回复、提问和权限请求推送到 iPhone。 | 暂不支持 |
| [opencode-quota](https://github.com/slkiser/opencode-quota) | 显示 Copilot、Z.ai、Kimi、OpenCode Go 等的额度和 token 用量，不污染上下文窗口。 | 支持，5.x 及以上 |
| [Plannotator](https://github.com/backnotprop/plannotator) | 在实施前审阅、批注 plan agent 的计划。SETUP.md 会装一个向它提交计划的 plan 提示词。 | 支持 |
| [cc-safety-net](https://github.com/kenryu42/cc-safety-net) | 拦截危险的 shell 命令，比如在项目外 `rm -rf`、`git push --force`。 | 支持 |
| [opencode-notifier](https://github.com/mohak34/opencode-notifier) | agent 完成或需要权限时，弹桌面通知并播放提示音。OpenCode 2 自带通知，避免重复的方法见它的 README。 | 支持 |

在 OpenCode 2 上，插件写在 `opencode.json` 的 `plugins` 下；tps-meter 这类只用于 TUI 的插件写在 `cli.json` 里。
具体见各插件的 README。

## 用 Magpie 测量

[Magpie](https://github.com/yetone/magpie) 让所有 coding agent 的模型都经过同一个本地网关，它的上下文
页面会显示每个 agent 的提示词由哪些部分组成。它的"起步轻"分数，是拿每个请求固定携带的部分和模型的上下文
窗口比：占 5% 及以下满分，占 30% 为零分。

## 许可证

[MIT](LICENSE)
