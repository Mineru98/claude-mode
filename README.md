# claude-mode

Claude Code 에 `claude --mode <name>` 을 더하는 zsh 래퍼입니다.

`--mode` 는 `settings/settings.<name>.json` 을 이번 세션의 `claude --settings` 로만 넘깁니다. `~/.claude/settings.json` 은 바꾸지 않습니다.

## 설치

[Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) 와 [jq](https://jqlang.github.io/jq/) 가 필요합니다.

```zsh
git clone https://github.com/Mineru98/claude-mode.git
```

`~/.zshrc` 에 한 줄을 넣습니다.

```zsh
[ -f ~/path/to/claude-mode/claude-mode.zsh ] && source ~/path/to/claude-mode/claude-mode.zsh
```

이 파일을 source 하면 `claude` / `cc` 가 래퍼가 됩니다. `--mode` 가 없으면 인자를 그대로 `command claude` 로 넘깁니다.

## 사용

```text
claude --mode                        모드 목록
claude --mode default                default 설정으로 실행
claude --mode research --resume      모드 + Claude Code 인자
claude --mode=ui                     등호 형태
cc --mode slide                      claude 와 동일
```

`--mode` 는 래퍼가 소비합니다. 나머지 인자는 Claude Code 로 전달됩니다.

이미 `--settings` 가 있으면 모드 설정 파일은 건너뜁니다. `settings/mcp.<name>.json` 이 있으면 `--mcp-config` 로 붙입니다. 이미 `--mcp-config` 가 있으면 MCP 파일은 건너뜁니다.

## 모드 파일이 하는 일

모드 JSON 은 Claude Code 세션 설정입니다. 보통 다음을 넣습니다.

- `enabledPlugins` — 쓰지 않는 플러그인은 `false`
- `skillOverrides` — 쓰지 않는 스킬 이름은 `"off"`
- `deniedMcpServers` — 이 모드에서 막을 MCP

`skillOverrides` 는 플러그인 스킬을 끄지 않습니다. 플러그인 스킬은 `enabledPlugins` 로 끕니다.

`~/.claude/settings.local.json` 의 `skillOverrides` 가 있으면 모드 파일과 합칩니다. 같은 키는 모드 파일이 이깁니다.

MCP 서버 정의는 `~/.claude.json` 에 있습니다. 한 모드에만 서버를 더하려면 `settings/mcp.<name>.json` 을 두면 됩니다.

## 들어 있는 모드

| 이름 | 파일 |
|------|------|
| `default` | `settings/settings.default.json` |
| `dev` | `settings/settings.dev.json` |
| `n8n` | `settings/settings.n8n.json` |
| `research` | `settings/settings.research.json` |
| `slide` | `settings/settings.slide.json` |
| `ui` | `settings/settings.ui.json` |
| `write` | `settings/settings.write.json` |

## 모드 추가

`settings/settings.<name>.json` 을 만들면 됩니다. 이름은 `[A-Za-z0-9][A-Za-z0-9_-]*` 만 허용합니다.

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "enabledPlugins": {},
  "skillOverrides": {}
}
```
