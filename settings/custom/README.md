# settings/custom — 개인 커스텀 프로필

공식 마켓플레이스가 아닌, 직접 추가한 마켓플레이스(`@omc`, `@ouroboros`, `@samsara`, `@im-not-ai`)를 조합한 프로필들입니다.

상위 `settings/` 의 모드 파일이 **직업(페르소나)** 기준이라면, 여기는 **어느 에이전트 프레임워크를 태울지** 기준입니다. 셋 다 켜면 스킬 이름이 겹치고 컨텍스트도 크게 먹으므로, 한 번에 하나만 태우려고 나눠 둔 것입니다.

## 먼저: 이 파일들은 `claude --mode` 로 안 잡힙니다

래퍼는 `settings/settings.*.json` 만 훑습니다(`_cc_list_modes`). 하위 디렉터리는 보지 않으므로 `settings/custom/*.json` 은 모드 목록에 나오지 않습니다.

쓰는 방법은 셋 중 하나입니다.

```bash
# 1) 그때그때 직접 넘기기 (가장 안전, 아무것도 안 건드림)
claude --settings ~/.claude-mode/settings/custom/settings.samsara-only.json

# 2) 모드로 승격 — 심볼릭 링크 (원본 하나만 고치면 됨)
ln -s custom/settings.samsara-only.json settings/settings.samsara.json

# 3) 모드로 승격 — 복사 (모드용으로 따로 손볼 거면)
cp settings/custom/settings.samsara-only.json settings/settings.samsara.json
```

2·3번을 하면 `claude --mode samsara` 로 쓸 수 있습니다.

> `--settings` 로 직접 넘기면 래퍼의 `settings.local.json` 병합(아래 참고)을 타지 않습니다. 그 병합이 필요하면 모드로 승격해서 쓰세요.

## 프로필 비교

| | `omc-only` | `ouroboros-omc` | `ouroboros-only` | `samsara-only` |
|---|---|---|---|---|
| `oh-my-claudecode@omc` | ✅ | ✅ | ✅ | ❌ |
| `ouroboros@ouroboros` | ❌ | ✅ | **❌** | ❌ |
| `samsara@samsara` | ❌ | ❌ | ❌ | ✅ |
| `humanize-korean@im-not-ai` | ❌ | ❌ | ✅ | ❌ |
| `frontend-design` | ❌ | ✅ | ✅ | ✅ |
| `chrome-devtools-mcp` / `typescript-lsp` | ✅ | ✅ | ✅ | ✅ |
| OMC 스킬 50개 `off` | ✅ | ❌ (전부 살림) | ✅ | ✅ |

네 파일 모두 `disableClaudeAiConnectors: true` 이고, `greptile` · `ralph-loop` · `skill-creator` · `superpowers` 는 항상 꺼져 있습니다.

각 프로필의 의도:

- **`ouroboros-omc`** — 유일하게 `skillOverrides` 가 비어 있습니다. OMC 스킬을 전부 살린 채 Ouroboros 까지 얹는, 제일 무거운 "다 켜기" 조합입니다.
- **`samsara-only`** — SAMSARA 이슈 워크플로만 남깁니다. OMC 플러그인과 OMC 스킬을 양쪽에서 끕니다.
- **`omc-only`** — OMC 플러그인만 켭니다. 다만 아래 "점검"을 보세요.
- **`ouroboros-only`** — 이름과 내용이 어긋나 있습니다. 아래 "점검"을 보세요.

## `skillOverrides` 목록이 왜 이렇게 긴가

OMC 는 **npm 설치본**이라 스킬이 `~/.claude/skills/` 에 개별 디렉터리로 깔립니다(현재 41개). 플러그인이 아니라 사용자 스킬이므로 `skillOverrides` 로 하나씩 끌 수 있습니다. 그래서 50줄짜리 목록이 있는 것입니다.

반대로 **플러그인이 제공하는 스킬은 `skillOverrides` 로 못 끕니다.** 플러그인 스킬은 `enabledPlugins` 를 `false` 로 두는 것 말고는 방법이 없습니다. 이 구분이 이 디렉터리 설계의 핵심입니다.

```
~/.claude/skills/*        → skillOverrides 로 끈다 (OMC npm 설치본)
enabledPlugins 의 플러그인 → enabledPlugins 를 false 로 둔다 (SAMSARA, Ouroboros, ...)
```

확인:

```bash
ls ~/.claude/skills          # skillOverrides 가 먹히는 대상
command -v omc               # npm 설치본이 있는지
```

## 점검 — 지금 상태에서 어긋난 것들

실제 설치 상태(`~/.claude/skills`, `~/.claude.json`)와 대조한 결과입니다.

### 1. `ouroboros-only.json` 에서 정작 ouroboros 가 꺼져 있음

```json
"ouroboros@ouroboros": false,
"humanize-korean@im-not-ai": true
```

파일 이름대로라면 `ouroboros` 가 `true` 여야 합니다. 지금 내용은 사실상 "humanize-korean 만 켠 프로필" 입니다. 의도한 게 후자라면 파일 이름을 `settings.humanize-only.json` 쪽으로 바꾸는 편이 헷갈리지 않습니다.

### 2. `omc-only.json` 은 OMC 를 켜면서 OMC 스킬을 끔

`oh-my-claudecode@omc: true` 로 플러그인 사본을 켜고, 동시에 `skillOverrides` 로 npm 사본 스킬 50개를 끕니다. 결과적으로 남는 건 플러그인 쪽 스킬뿐입니다. 노린 것이면 그대로 두고, "OMC 를 제대로 다 쓰는 프로필" 을 원했던 거라면 `skillOverrides` 를 비우세요(= `ouroboros-omc` 에서 ouroboros 만 끈 형태).

### 3. `skillOverrides` 에 없어진 스킬 이름 15개가 남아 있음

OMC 5.0.0 에서 없어졌거나 이름이 바뀐 것들입니다. 동작에 해는 없지만 목록만 길어집니다.

```
ccg, deep-dive, learner, local-build-reminder, mcp-setup, merge-readiness,
omc-reference, omc-teams, plan, review, sciomc, setup, ultraqa, ultrawork, writer-memory
```

(`plan` / `review` 는 현재 `omc-plan` / `omc-review` 로 깔려 있고, 그 이름은 목록에 이미 들어 있습니다.)

### 4. 반대로 목록에서 빠져 안 꺼지는 스킬 4개

"전부 끈다" 는 의도라면 아래를 추가해야 합니다.

```
aside-browser, find-skills, visual-companion, make-interfaces-feel-better
```

`make-interfaces-feel-better` 는 상위 모드 파일들이 이미 개별로 다루고 있으니, 여기서도 끌지는 취향에 맞춰 결정하세요.

아래 유지보수 스니펫을 돌리면 `ouroboros` 도 같이 나옵니다. 이건 `~/.claude/skills/ouroboros` 에 깔린 **로컬 스킬**이고 `ouroboros@ouroboros` **플러그인과 별개**입니다. 플러그인을 꺼도 이 로컬 스킬은 남으므로, Ouroboros 를 완전히 빼려면 `enabledPlugins` 와 `skillOverrides` 양쪽에서 꺼야 합니다.

### 5. `deniedMcpServers` 이름이 실제 서버 이름과 다름

```json
"deniedMcpServers": [
  { "serverName": "n8n-mcp" },
  { "serverName": "mermaid-validator" }
]
```

`~/.claude.json` 에 전역으로 등록된 이름은 **`n8n-dev`, `n8n-prod`, `mermaid-validator`** 입니다. `n8n-mcp` 는 특정 프로젝트에만 있는 이름이라, 전역에서는 아무것도 막지 못합니다. n8n 을 확실히 막으려면 이렇게 바꿔야 합니다.

```json
"deniedMcpServers": [
  { "serverName": "n8n-dev" },
  { "serverName": "n8n-prod" },
  { "serverName": "mermaid-validator" }
]
```

상위 `settings/settings.*.json` 이 쓰는 `{ "serverName": "n8n" }` 도 같은 이유로 매칭되지 않습니다.

확인:

```bash
jq -r '.mcpServers | keys[]' ~/.claude.json
```

## 유지보수

`skillOverrides` 50줄은 `omc-only` · `ouroboros-only` · `samsara-only` 세 파일에 **똑같이 복사돼 있습니다**(`ouroboros-omc` 만 비어 있음). 한 곳을 고치면 나머지 두 곳도 같이 고쳐야 합니다.

```bash
# 세 파일의 skillOverrides 키가 아직 같은지 확인
for f in settings/custom/settings.{omc-only,ouroboros-only,samsara-only}.json; do
  printf '%-46s %s\n' "$f" "$(jq -S '.skillOverrides|keys' "$f" | md5sum 2>/dev/null || jq -S '.skillOverrides|keys' "$f" | md5)"
done
```

목록이 실제 설치본과 맞는지 훑어보는 한 줄입니다.

```bash
# off 목록에 없어서 살아있는 스킬 / 목록에만 있고 실체 없는 이름
python3 - <<'EOF'
import json, os
off  = set(json.load(open("settings/custom/settings.samsara-only.json"))["skillOverrides"])
have = {d for d in os.listdir(os.path.expanduser("~/.claude/skills")) if not d.startswith(".")}
print("안 꺼진 것 :", ", ".join(sorted(have - off)) or "없음")
print("죽은 이름  :", ", ".join(sorted(off - have)) or "없음")
EOF
```

JSON 문법 검사:

```bash
for f in settings/custom/*.json; do jq -e 'type == "object"' "$f" >/dev/null || echo "BAD $f"; done
```

## 쓰는 플러그인 / MCP

| 이름 | 마켓플레이스 키 | 용도 |
|------|------------------|------|
| [samsara](https://github.com/Mineru98/samsara) | `samsara@samsara` | GitHub 이슈 기반 워크트리 개발 워크플로 (`issue-create` → `start` → `end` → `merge`) |
| [ouroboros](https://github.com/Q00/ouroboros) | `ouroboros@ouroboros` | 인터뷰 → Seed → 실행 → 평가 → 진화 루프 |
| [oh-my-claudecode](https://github.com/yeachan-heo/oh-my-claudecode) | `oh-my-claudecode@omc` | 멀티 에이전트 오케스트레이션. **npm 설치본은 `~/.claude/skills/` 에 깔림** |
| [im-not-ai](https://github.com/epoko77-ai/im-not-ai) | `humanize-korean@im-not-ai` | 한국어 문장 다듬기 |
| [n8n-mcp](https://github.com/czlonkowski/n8n-mcp) | (MCP) | n8n 워크플로 제어. 전역 등록명은 `n8n-dev` / `n8n-prod` |
| [mermaid-validator](https://github.com/rtuin/mcp-mermaid-validator) | (MCP) | mermaid 다이어그램 문법 검증 |

플러그인 키는 항상 `<플러그인 이름>@<마켓플레이스 이름>` 입니다. 마켓플레이스가 안 붙어 있으면 그 줄은 그냥 무시됩니다.

```bash
ls ~/.claude/plugins/marketplaces                       # 붙어 있는 마켓플레이스
jq -r '.enabledPlugins | to_entries[] | "\(.value)\t\(.key)"' ~/.claude/settings.json
```
