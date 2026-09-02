# claude-mode

Claude Code 에 `claude --mode <name>` 을 더하는 셸 래퍼입니다. **bash 와 zsh 를 모두 지원합니다.**

`--mode` 는 `settings/settings.<name>.json` 을 이번 세션의 `claude --settings` 로만 넘깁니다. `~/.claude/settings.json` 은 바꾸지 않습니다.

래퍼 파일은 **source 전용**입니다. `bash claude-mode.bash` 처럼 실행하면 함수가 그 서브셸에서만 생겼다가 사라집니다.

| 셸 | 파일 |
|----|------|
| zsh | `claude-mode.zsh` |
| bash | `claude-mode.bash` |

## 설치방법

```bash
curl -fsSL https://raw.githubusercontent.com/Mineru98/claude-mode/refs/heads/main/install.sh | sh
```

`sh` 로 도는 POSIX 스크립트라서 oh-my-zsh 를 안 써도, zsh 를 안 써도 됩니다. 하는 일은 이렇습니다.

1. `jq` / `git` 또는 `curl` / `bash` 또는 `zsh` 가 있는지 확인합니다. 없으면 OS 에 맞는 설치 명령을 알려주고 멈춥니다. `claude` 가 없으면 경고만 하고 계속합니다.
2. 저장소를 `~/.claude-mode` 로 받습니다. `git` 이 없으면 tarball 을 내려받아 풉니다. 이미 있으면 그 자리에서 업데이트합니다.
3. 쓰는 셸에 맞춰 `~/.zshrc` / `~/.bashrc` 끝에 관리 블록을 넣습니다. 처음 넣을 때 `<rc>.claude-mode.bak` 백업을 남깁니다.

같은 명령을 다시 돌리면 최신으로 업데이트하고 블록을 갱신합니다. 블록이 중복되지 않습니다.

### 설치 옵션

환경변수로 바꿉니다.

```bash
# 다른 경로에 설치
curl -fsSL .../install.sh | CLAUDE_MODE_HOME="$HOME/dev/claude-mode" sh

# rc 파일을 건드리지 말고, 넣을 블록만 출력
curl -fsSL .../install.sh | CLAUDE_MODE_SHELL=none sh

# bash 와 zsh 양쪽 rc 에 모두 넣기
curl -fsSL .../install.sh | CLAUDE_MODE_SHELL=both sh
```

| 변수 | 기본값 | 뜻 |
|------|--------|-----|
| `CLAUDE_MODE_HOME` | `~/.claude-mode` | 설치 경로 |
| `CLAUDE_MODE_SHELL` | `auto` | rc 를 건드릴 셸: `auto` / `bash` / `zsh` / `both` / `none` |
| `CLAUDE_MODE_REF` | `main` | 받을 branch / tag |
| `CLAUDE_MODE_REPO` | GitHub 저장소 | 다른 fork 를 쓸 때 |

`auto` 는 `$SHELL` 을 먼저 보고, 다른 셸의 rc 파일이 이미 있으면 거기도 같이 넣습니다. macOS 에서 `~/.bash_profile` 이 `~/.bashrc` 를 안 읽고 있으면 `~/.bash_profile` 에도 넣습니다.

### 설치 확인

```bash
claude --mode
```

모드 목록이 인쇄되면 된 것입니다. 안 되면 새 터미널 탭을 열어보세요.

`claude` 가 함수가 아니라 바이너리로 보이면 rc 블록이 로드되지 않은 것입니다.

```bash
type claude    # bash
whence -v cc   # zsh
```

### 지우기

rc 파일에서 `# >>> claude-mode >>>` ~ `# <<< claude-mode <<<` 블록을 지우고, 설치 경로를 삭제합니다.

```bash
rm -rf ~/.claude-mode
```

## 필요 조건

- bash 또는 zsh
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude` 가 PATH 에 있어야 함)
- [jq](https://jqlang.github.io/jq/) — 모드 설정과 `settings.local.json` 을 합칠 때 씁니다
- 설치 스크립트를 쓴다면 `git` 또는 `curl`

확인:

```bash
command -v claude
command -v jq
```

## 직접 설치하기

설치 스크립트를 안 쓰고 손으로 넣는 방법입니다.

```bash
git clone https://github.com/Mineru98/claude-mode.git ~/.claude-mode
```

`~/.bashrc` 또는 `~/.zshrc` 끝에 아래를 넣습니다. 두 셸 모두에서 동작하는 블록입니다.

```bash
CLAUDE_MODE_HOME="$HOME/.claude-mode"
if [ -n "${ZSH_VERSION-}" ] && [ -f "$CLAUDE_MODE_HOME/claude-mode.zsh" ]; then
  . "$CLAUDE_MODE_HOME/claude-mode.zsh"
elif [ -n "${BASH_VERSION-}" ] && [ -f "$CLAUDE_MODE_HOME/claude-mode.bash" ]; then
  . "$CLAUDE_MODE_HOME/claude-mode.bash"
fi
```

### oh-my-zsh 를 쓴다면

`source $ZSH/oh-my-zsh.sh` **뒤에** 두어야 합니다. 앞에 두면 플러그인이 나중에 정의하는 alias 에 밀립니다.

이미 `claude` 나 `cc` 를 정의하는 다른 래퍼를 source 하고 있으면 **나중에 source 한 쪽이 이깁니다.** 두 래퍼를 같이 쓰지 마세요.

`cc` 도 같은 래퍼입니다. `claude` 만 쓰고 싶으면 source 뒤에 `unset -f cc` (bash) 또는 `unfunction cc` (zsh) 하면 됩니다.

### 적용

새 터미널 탭을 여는 것이 가장 안전합니다. 이미 열린 셸에 바로 넣으려면 `. ~/.bashrc` 또는 `source ~/.zshrc` 를 씁니다.

Powerlevel10k instant prompt 를 쓰면 이미 뜬 zsh 에서 `source ~/.zshrc` 할 때 console output 경고가 날 수 있습니다. 그 경우 새 탭을 쓰세요.

## 사용

```text
claude --mode                        모드 목록
claude --mode default                default 설정으로 실행
claude --mode research --resume      모드 + Claude Code 인자
claude --mode=ui                     등호 형태
cc --mode slide                      claude 와 동일
```

`--mode` 는 래퍼가 소비합니다. 나머지 인자는 Claude Code 로 전달됩니다. `--mode` 가 없으면 인자를 그대로 `command claude` 로 넘깁니다.

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

| 이름 | 페르소나 | 켜는 플러그인 |
|------|----------|----------------|
| `backend` | TypeScript 백엔드 개발자 | typescript-lsp, serena, context7, prisma, postman, commit-commands |
| `data-eng` | 데이터 엔지니어 | data-engineering, duckdb-skills, mongodb, context7, commit-commands |
| `data-science` | 데이터 분석가 | pyright-lsp, duckdb-skills, bigquery-data-analytics, context7, claude-md-management |
| `default` | 기본값 (플러그인 지정 없음) | — |
| `frontend` | TypeScript + React 프론트엔드 개발자 | typescript-lsp, frontend-design, modern-web-guidance, chrome-devtools-mcp, context7, commit-commands |
| `ml` | ML / 모델 엔지니어 | pyright-lsp, huggingface-skills, mlflow, duckdb-skills, context7 |
| `n8n` | n8n 워크플로 작업 | ui-ux-pro-max |
| `ops` | 배포 / 운영 | github, vercel, sentry, postman, commit-commands |
| `research` | 연구자 | exa, tavily, firecrawl, context7, notion |
| `review` | 코드 리뷰어 | code-review, pr-review-toolkit, code-simplifier, security-guidance, github |
| `slide` | 프레젠테이션 디자이너 | frontend-slides, ui-ux-pro-max, frontend-design, canva |
| `study` | 학습자 | learn-with-coursera, explanatory-output-style, math-olympiad, context7 |
| `ui` | 웹 + 모션 디자이너 | frontend-design, superdesign, figma, chrome-devtools-mcp, modern-web-guidance, ui-ux-pro-max |
| `write` | 문서 작성가 | notion, mintlify, exa, ckeditor, claude-md-management |

각 모드 파일은 `settings/settings.<name>.json` 이고, 컨텍스트를 아끼려고 활성 플러그인을 모드당 4~6개로 제한합니다. 각 파일 `enabledPlugins` 아래쪽에는 그 페르소나에서 다음으로 켤 만한 후보를 `false` 로 적어 두었으니, 필요하면 값만 `true` 로 바꾸면 됩니다.

## 모드 추가

`settings/settings.<name>.json` 을 만들면 됩니다. 이름은 `[A-Za-z0-9][A-Za-z0-9_-]*` 만 허용합니다. bash / zsh 래퍼가 알아서 같이 인식합니다.

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "enabledPlugins": {},
  "skillOverrides": {}
}
```
