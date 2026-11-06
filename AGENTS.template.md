<!-- A starting point for ~/.config/opencode/AGENTS.md. It is sent with every request: keep it
     short (aim for under 4,000 characters) and delete any section you don't use. -->

## Coding principles

1. **Think before coding**: state assumptions; ask rather than guess when a request is ambiguous; push back when a simpler way exists.
2. **Simplicity first**: the minimum code that solves the problem; no speculative abstraction or unrequested features.
3. **Surgical changes**: touch only what the task needs; match the existing style; don't refactor unrelated code.
4. **Goal-driven**: define how success is verified (tests pass, command succeeds) and loop until it is.

## Tool routing

<!-- One line per tool the agent would not find on its own. Examples: -->
- **Read a URL**: `webfetch`.
- **Library docs**: `webfetch` on the library's docs site, anchored to the version in use.
- **Project-only MCP servers**: `<name>` is enabled only in `<project path>`.
