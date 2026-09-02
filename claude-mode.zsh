#!/usr/bin/env zsh
# Claude Code --mode wrapper — claude --mode <name>
# source 전용. zshrc 넣는 법은 README.md 를 본다.
#
# ~/.zshrc (oh-my-zsh 보다 뒤, CLAUDE_MODE_HOME 은 clone 경로):
#   CLAUDE_MODE_HOME="$HOME/claude-mode"
#   [ -f "$CLAUDE_MODE_HOME/claude-mode.zsh" ] && source "$CLAUDE_MODE_HOME/claude-mode.zsh"
#
# claude --mode                        List wrapper modes (settings/settings.<name>.json)
# claude --mode default|research|...   Load that mode via claude --settings
# claude --mode-version                Print claude-mode version / install info
# claude --mode-help                   Print wrapper usage
# claude --mode-update [--check]       Compare with latest release, update in place

_CLAUDE_MODE_HOME="${${(%):-%x}:A:h}"

_cc_settings_dir() {
  print -r -- "${_CLAUDE_MODE_HOME}/settings"
}

_cc_mode_settings_file() {
  print -r -- "$(_cc_settings_dir)/settings.${1}.json"
}

_cc_install_info() {
  local key="$1" file="${_CLAUDE_MODE_HOME}/.install-info"
  [[ -f "$file" ]] || return 1
  local line
  line="$(grep -m1 "^${key}=" "$file" 2>/dev/null)" || return 1
  print -r -- "${line#*=}"
}

_cc_local_version() {
  local ver=''
  if [[ -f "${_CLAUDE_MODE_HOME}/VERSION" ]]; then
    ver="$(<"${_CLAUDE_MODE_HOME}/VERSION")"
    ver="${ver//[$'\n\r ']/}"
  fi
  [[ -n "$ver" ]] || ver='unknown'
  print -r -- "$ver"
}

_cc_slug() {
  print -r -- "${CLAUDE_MODE_SLUG:-Mineru98/claude-mode}"
}

# stdout: 최신 버전(앞의 v 를 뗀 것). 릴리스 태그를 먼저 보고, 없으면 main 의 VERSION.
_cc_latest_version() {
  local slug tag
  slug="$(_cc_slug)"
  (( ${+commands[curl]} )) || return 1
  tag="$(curl -fsSL "https://api.github.com/repos/${slug}/releases/latest" 2>/dev/null \
    | jq -r '.tag_name // empty' 2>/dev/null)"
  if [ -z "$tag" ]; then
    tag="$(curl -fsSL "https://raw.githubusercontent.com/${slug}/main/VERSION" 2>/dev/null \
      | tr -d '\n\r ')"
  fi
  [ -n "$tag" ] || return 1
  print -r -- "${tag#v}"
}

# $1 < $2 이면 0. 점으로 나눈 숫자 비교. unknown 은 항상 뒤로 본다.
_cc_ver_lt() {
  [ "$1" = "$2" ] && return 1
  [ "$1" = "unknown" ] && return 0
  [ "$2" = "unknown" ] && return 1
  awk -v a="$1" -v b="$2" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, ".")
    k = (n > m ? n : m)
    for (i = 1; i <= k; i++) {
      ai = (i <= n ? x[i] + 0 : 0); bi = (i <= m ? y[i] + 0 : 0)
      if (ai < bi) exit 0
      if (ai > bi) exit 1
    }
    exit 1
  }'
}

_cc_update() {
  local check_only=0 cur latest slug home tmp

  case "${1-}" in
    --check) check_only=1; shift ;;
    -*) print -ru2 "cc --mode-update: 모르는 옵션: ${1}"; return 1 ;;
  esac
  if [ "$#" -gt 0 ]; then
    print -ru2 "cc --mode-update: 남는 인자: $*"
    return 1
  fi

  home="$_CLAUDE_MODE_HOME"
  slug="$(_cc_slug)"
  cur="$(_cc_local_version)"

  latest="$(_cc_latest_version)" || {
    print -ru2 'cc --mode-update: 최신 버전을 확인하지 못했습니다 (curl / 네트워크 확인)'
    return 1
  }

  if [ "$cur" = "$latest" ]; then
    print -r -- "claude-mode ${cur} — 이미 최신입니다"
    return 0
  fi

  if ! _cc_ver_lt "$cur" "$latest"; then
    print -r -- "claude-mode ${cur} — 최신 릴리스(${latest})보다 앞서 있어 그대로 둡니다"
    return 0
  fi

  print -r -- "claude-mode ${cur} → ${latest}"
  (( check_only )) && return 0

  # 설치 스크립트는 git reset --hard / rm -rf 로 덮어쓴다. 작업 중인 체크아웃이면 멈춘다.
  # linked worktree 는 .git 이 파일이라 -d 로는 못 잡는다. git 에게 직접 묻는다.
  if command -v git >/dev/null 2>&1 \
     && git -C "$home" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
     && [ -n "$(git -C "$home" status --porcelain 2>/dev/null)" ]; then
    print -ru2 "cc --mode-update: ${home} 에 커밋 안 한 변경이 있어 멈춥니다"
    print -ru2 '  정리하거나 커밋한 뒤 다시 실행하세요.'
    return 1
  fi

  # curl 을 sh 에 바로 물리면 curl 이 실패해도 sh 가 빈 입력으로 0 을 준다.
  # 아무것도 설치 안 하고 "완료" 라고 말하게 되므로 파일로 받아 확인한다.
  tmp="$(mktemp "${TMPDIR:-/tmp}/claude-mode-install.XXXXXX")" || return 1
  if ! curl -fsSL -o "$tmp" "https://raw.githubusercontent.com/${slug}/main/install.sh"; then
    rm -f "$tmp"
    print -ru2 'cc --mode-update: install.sh 를 받지 못했습니다'
    return 1
  fi
  if ! CLAUDE_MODE_HOME="$home" CLAUDE_MODE_SLUG="$slug" CLAUDE_MODE_REF="v${latest}" sh "$tmp"; then
    rm -f "$tmp"
    print -ru2 'cc --mode-update: 업데이트에 실패했습니다'
    return 1
  fi
  rm -f "$tmp"

  print -r -- '업데이트 완료. 새 터미널을 열거나 다음을 실행하세요:'
  print -r -- "  source ${home}/claude-mode.zsh"
  return 0
}

_cc_print_version() {
  emulate -L zsh
  local ver='' ref='' commit='' date='' origin=''

  ver="$(_cc_local_version)"

  if [[ -d "${_CLAUDE_MODE_HOME}/.git" ]] && (( ${+commands[git]} )); then
    commit="$(git -C "$_CLAUDE_MODE_HOME" rev-parse --short HEAD 2>/dev/null)"
    ref="$(git -C "$_CLAUDE_MODE_HOME" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    [[ "$ref" == HEAD ]] && ref="$(_cc_install_info ref)"
    date="$(git -C "$_CLAUDE_MODE_HOME" log -1 --format=%cs 2>/dev/null)"
    [[ -n "$date" ]] || date="$(_cc_install_info date)"
    origin='git'
  else
    commit="$(_cc_install_info commit)"
    ref="$(_cc_install_info ref)"
    date="$(_cc_install_info date)"
    origin="$(_cc_install_info method)"
  fi

  local detail="${ref:-?}"
  [[ -n "$commit" ]] && detail+=" @ ${commit}"
  [[ -n "$date" ]] && detail+=", ${date}"
  print -r -- "claude-mode ${ver} (${detail})"
  print -r -- "  home   ${_CLAUDE_MODE_HOME}"
  print -r -- "  shell  zsh (claude-mode.zsh)"
  [[ -n "$origin" ]] && print -r -- "  origin ${origin}"
  return 0
}

_cc_print_help() {
  local usage="${_CLAUDE_MODE_HOME}/share/usage.txt"
  if [[ -f "$usage" ]]; then
    cat "$usage"
  else
    print -ru2 "cc: 도움말 파일이 없습니다: ${usage}"
    return 1
  fi
}

_cc_list_modes() {
  local dir="$(_cc_settings_dir)"
  local f mode
  local -a files=("$dir"/settings.*.json(N))
  if (( ${#files} == 0 )); then
    print -u2 "cc --mode: ${dir} 에 settings.<mode>.json 이 없습니다"
    return 1
  fi
  print -r -- 'cc --mode <name>  →  settings/settings.<name>.json 을 --settings 로 로드'
  print -r -- 'optional          →  settings/mcp.<name>.json 이 있으면 --mcp-config 로 로드'
  for f in "${files[@]}"; do
    mode="${f:t}"
    mode="${mode#settings.}"
    mode="${mode%.json}"
    print -r -- "  ${mode}"
  done
}

# Strip wrapper --mode / --mode= from argv. Sets _cc_mode and _cc_applied_args.
# _cc_mode is empty (omitted), "-" (flag with no value), or the mode name.
_cc_extract_mode() {
  emulate -L zsh
  local -a src=("$@") out=()
  local i=1 mode="" saw=0

  _cc_mode=""
  while (( i <= ${#src} )); do
    case "${src[i]}" in
      --)
        out+=("${src[@]:$i-1}")
        break
        ;;
      --mode)
        if (( saw )); then
          print -u2 'cc --mode: --mode 는 한 번만 쓸 수 있습니다'
          return 1
        fi
        saw=1
        if (( i < ${#src} )) && [[ "${src[i+1]}" != -* ]]; then
          mode="${src[i+1]}"
          (( i++ ))
        else
          mode="-"
        fi
        ;;
      --mode=*)
        if (( saw )); then
          print -u2 'cc --mode: --mode 는 한 번만 쓸 수 있습니다'
          return 1
        fi
        saw=1
        mode="${src[i]#--mode=}"
        [[ -n "$mode" ]] || mode="-"
        ;;
      *)
        out+=("${src[i]}")
        ;;
    esac
    (( i++ ))
  done

  _cc_mode="$mode"
  _cc_applied_args=("${out[@]}")
  return 0
}

# Merge mode settings with ~/.claude/settings.local.json skillOverrides (mode wins).
# Writes a resolved file and prints its path.
_cc_resolve_mode_settings() {
  emulate -L zsh
  local mode_file="$1"
  local local_file="${HOME}/.claude/settings.local.json"
  local out="${TMPDIR:-/tmp}/cc-settings-${USER:-user}-${mode_file:t}"

  if [[ -f "$local_file" ]]; then
    jq -n --slurpfile mode "$mode_file" --slurpfile local "$local_file" '
      ($mode[0] // {}) as $m
      | ($local[0].skillOverrides // {}) as $loc
      | $m + {skillOverrides: ($loc + ($m.skillOverrides // {}))}
      | if (.skillOverrides | length) == 0 then del(.skillOverrides) else . end
    ' > "$out" || return 1
  else
    cp "$mode_file" "$out" || return 1
  fi
  print -r -- "$out"
}

_cc_inject_mode_settings() {
  emulate -L zsh
  local mode="$1"
  shift
  local -a src=("$@") extra=()
  local file resolved mcp a have_settings=0 have_mcp=0 insert_at j

  if [[ ! "$mode" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
    print -u2 "cc --mode: 잘못된 모드 이름: ${mode}"
    return 1
  fi

  file="$(_cc_mode_settings_file "$mode")"
  if [[ ! -f "$file" ]]; then
    print -u2 "cc --mode: 설정 파일이 없습니다: ${file}"
    _cc_list_modes
    return 1
  fi
  if (( ! ${+commands[jq]} )) || ! jq -e 'type == "object"' "$file" >/dev/null 2>&1; then
    print -u2 "cc --mode: 잘못된 JSON: ${file}"
    return 1
  fi

  for a in "${src[@]}"; do
    [[ "$a" == "--" ]] && break
    case "$a" in
      --settings|--settings=*) have_settings=1 ;;
      --mcp-config|--mcp-config=*) have_mcp=1 ;;
    esac
  done

  if (( have_settings )); then
    print -u2 "cc --mode: --settings 가 이미 있어 ${file} 을 건너뜁니다"
  else
    resolved="$(_cc_resolve_mode_settings "$file")" || return 1
    extra+=(--settings "$resolved")
  fi

  mcp="$(_cc_settings_dir)/mcp.${mode}.json"
  if [[ -f "$mcp" ]]; then
    if (( have_mcp )); then
      print -u2 "cc --mode: --mcp-config 가 이미 있어 ${mcp} 을 건너뜁니다"
    else
      extra+=(--mcp-config "$mcp")
    fi
  fi

  if (( ${#extra} == 0 )); then
    _cc_applied_args=("${src[@]}")
    return 0
  fi

  # --tmux --resume 가 $1 을 보도록, wrapper 플래그 앞이 아니라 `--` 앞(없으면 끝)에 붙인다.
  insert_at=0
  for (( j = 1; j <= ${#src}; j++ )); do
    if [[ "${src[j]}" == "--" ]]; then
      insert_at=j
      break
    fi
  done
  if (( insert_at )); then
    src[insert_at,0]=("${extra[@]}")
  else
    src+=("${extra[@]}")
  fi
  _cc_applied_args=("${src[@]}")
  return 0
}

cc() {
  local _cc_mode=""
  local -a _cc_applied_args=()

  # 래퍼 전용 플래그. 맨 앞에 올 때만 잡는다.
  # 뒤쪽까지 훑으면 `claude -p --mode-version` 처럼 다른 옵션의 값으로 온 것까지
  # 가로채게 된다. 이 둘은 단독으로 쓰는 정보성 플래그라 첫 인자로 충분하다.
  case "${1-}" in
    --mode-version) _cc_print_version; return ;;
    --mode-help)    _cc_print_help;    return ;;
    --mode-update)  shift; _cc_update "$@"; return ;;
  esac

  _cc_extract_mode "$@" || return
  set -- "${_cc_applied_args[@]}"

  if [[ "$_cc_mode" == "-" ]]; then
    if (( $# )); then
      print -u2 'cc --mode: 모드 이름이 필요합니다 (예: cc --mode default)'
      _cc_list_modes
      return 1
    fi
    _cc_list_modes
    return
  fi

  if [[ -n "$_cc_mode" ]]; then
    _cc_inject_mode_settings "$_cc_mode" "$@" || return
    set -- "${_cc_applied_args[@]}"
  fi

  command claude "$@"
}
claude() { cc "$@"; }
