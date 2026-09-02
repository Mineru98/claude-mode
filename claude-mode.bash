#!/usr/bin/env bash
# Claude Code --mode wrapper — claude --mode <name>
# claude-mode.zsh 의 bash 포팅. 동작은 같다.
# source 전용. 설치는 install.sh 또는 README.md 를 본다.
#
# ~/.bashrc:
#   CLAUDE_MODE_HOME="$HOME/.claude-mode"
#   [ -f "$CLAUDE_MODE_HOME/claude-mode.bash" ] && . "$CLAUDE_MODE_HOME/claude-mode.bash"
#
# claude --mode                        List wrapper modes (settings/settings.<name>.json)
# claude --mode default|research|...   Load that mode via claude --settings
# claude --mode-version                Print claude-mode version / install info
# claude --mode-help                   Print wrapper usage
# claude --mode-update [--check]       Compare with latest release, update in place

_CLAUDE_MODE_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

_cc_settings_dir() {
  printf '%s\n' "${_CLAUDE_MODE_HOME}/settings"
}

_cc_mode_settings_file() {
  printf '%s\n' "$(_cc_settings_dir)/settings.${1}.json"
}

_cc_install_info() {
  local key="$1" file="${_CLAUDE_MODE_HOME}/.install-info" line
  [ -f "$file" ] || return 1
  line="$(grep -m1 "^${key}=" "$file" 2>/dev/null)" || return 1
  [ -n "$line" ] || return 1
  printf '%s\n' "${line#*=}"
}

_cc_local_version() {
  local ver=''
  if [ -f "${_CLAUDE_MODE_HOME}/VERSION" ]; then
    ver="$(tr -d '\n\r ' < "${_CLAUDE_MODE_HOME}/VERSION" 2>/dev/null)"
  fi
  [ -n "$ver" ] || ver='unknown'
  printf '%s\n' "$ver"
}

_cc_slug() {
  printf '%s\n' "${CLAUDE_MODE_SLUG:-Mineru98/claude-mode}"
}

# stdout: 최신 버전(앞의 v 를 뗀 것). 릴리스 태그를 먼저 보고, 없으면 main 의 VERSION.
_cc_latest_version() {
  local slug tag
  slug="$(_cc_slug)"
  command -v curl >/dev/null 2>&1 || return 1
  tag="$(curl -fsSL "https://api.github.com/repos/${slug}/releases/latest" 2>/dev/null \
    | jq -r '.tag_name // empty' 2>/dev/null)"
  if [ -z "$tag" ]; then
    tag="$(curl -fsSL "https://raw.githubusercontent.com/${slug}/main/VERSION" 2>/dev/null \
      | tr -d '\n\r ')"
  fi
  [ -n "$tag" ] || return 1
  printf '%s\n' "${tag#v}"
}

_cc_update() {
  local check_only=0 cur latest slug home

  case "${1-}" in
    --check) check_only=1 ;;
    '') ;;
    *) printf '%s\n' "cc --mode-update: 모르는 옵션: ${1}" >&2; return 1 ;;
  esac

  home="$_CLAUDE_MODE_HOME"
  slug="$(_cc_slug)"
  cur="$(_cc_local_version)"

  latest="$(_cc_latest_version)" || {
    printf '%s\n' 'cc --mode-update: 최신 버전을 확인하지 못했습니다 (curl / 네트워크 확인)' >&2
    return 1
  }

  if [ "$cur" = "$latest" ]; then
    printf '%s\n' "claude-mode ${cur} — 이미 최신입니다"
    return 0
  fi

  printf '%s\n' "claude-mode ${cur} → ${latest}"
  [ "$check_only" -eq 1 ] && return 0

  # 설치 스크립트는 git reset --hard / rm -rf 로 덮어쓴다. 개발 중인 체크아웃이면 멈춘다.
  if [ -d "$home/.git" ] && command -v git >/dev/null 2>&1 \
     && [ -n "$(git -C "$home" status --porcelain 2>/dev/null)" ]; then
    printf '%s\n' "cc --mode-update: ${home} 에 커밋 안 한 변경이 있어 멈춥니다" >&2
    printf '%s\n' '  정리하거나 커밋한 뒤 다시 실행하세요.' >&2
    return 1
  fi

  curl -fsSL "https://raw.githubusercontent.com/${slug}/main/install.sh" \
    | CLAUDE_MODE_HOME="$home" CLAUDE_MODE_REF="v${latest}" sh || return 1

  printf '%s\n' "업데이트 완료. 새 터미널을 열거나 다음을 실행하세요:"
  printf '%s\n' "  source ${home}/claude-mode.bash"
  return 0
}

_cc_print_version() {
  local ver='' ref='' commit='' date='' origin='' detail=''

  ver="$(_cc_local_version)"

  if [ -d "${_CLAUDE_MODE_HOME}/.git" ] && command -v git >/dev/null 2>&1; then
    commit="$(git -C "$_CLAUDE_MODE_HOME" rev-parse --short HEAD 2>/dev/null)"
    ref="$(git -C "$_CLAUDE_MODE_HOME" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    [ "$ref" = "HEAD" ] && ref="$(_cc_install_info ref)"
    date="$(git -C "$_CLAUDE_MODE_HOME" log -1 --format=%cs 2>/dev/null)"
    [ -n "$date" ] || date="$(_cc_install_info date)"
    origin='git'
  else
    commit="$(_cc_install_info commit)"
    ref="$(_cc_install_info ref)"
    date="$(_cc_install_info date)"
    origin="$(_cc_install_info method)"
  fi

  detail="${ref:-?}"
  [ -n "$commit" ] && detail="${detail} @ ${commit}"
  [ -n "$date" ] && detail="${detail}, ${date}"
  printf '%s\n' "claude-mode ${ver} (${detail})"
  printf '%s\n' "  home   ${_CLAUDE_MODE_HOME}"
  printf '%s\n' "  shell  bash (claude-mode.bash)"
  [ -n "$origin" ] && printf '%s\n' "  origin ${origin}"
  return 0
}

_cc_print_help() {
  local usage="${_CLAUDE_MODE_HOME}/share/usage.txt"
  if [ -f "$usage" ]; then
    cat "$usage"
  else
    printf '%s\n' "cc: 도움말 파일이 없습니다: ${usage}" >&2
    return 1
  fi
}

_cc_list_modes() {
  local dir f mode
  local -a files=()
  dir="$(_cc_settings_dir)"
  for f in "$dir"/settings.*.json; do
    [ -e "$f" ] || continue
    files+=("$f")
  done
  if [ "${#files[@]}" -eq 0 ]; then
    printf '%s\n' "cc --mode: ${dir} 에 settings.<mode>.json 이 없습니다" >&2
    return 1
  fi
  printf '%s\n' 'cc --mode <name>  →  settings/settings.<name>.json 을 --settings 로 로드'
  printf '%s\n' 'optional          →  settings/mcp.<name>.json 이 있으면 --mcp-config 로 로드'
  for f in "${files[@]}"; do
    mode="${f##*/}"
    mode="${mode#settings.}"
    mode="${mode%.json}"
    printf '  %s\n' "$mode"
  done
}

# Strip wrapper --mode / --mode= from argv. Sets _cc_mode and _cc_applied_args.
# _cc_mode is empty (omitted), "-" (flag with no value), or the mode name.
_cc_extract_mode() {
  local -a src=("$@") out=()
  local i=0 n=$# mode="" saw=0

  _cc_mode=""
  while [ "$i" -lt "$n" ]; do
    case "${src[i]}" in
      --)
        while [ "$i" -lt "$n" ]; do
          out+=("${src[i]}")
          i=$((i + 1))
        done
        break
        ;;
      --mode)
        if [ "$saw" -eq 1 ]; then
          printf '%s\n' 'cc --mode: --mode 는 한 번만 쓸 수 있습니다' >&2
          return 1
        fi
        saw=1
        if [ $((i + 1)) -lt "$n" ] && [ "${src[i + 1]#-}" = "${src[i + 1]}" ]; then
          mode="${src[i + 1]}"
          i=$((i + 1))
        else
          mode="-"
        fi
        ;;
      --mode=*)
        if [ "$saw" -eq 1 ]; then
          printf '%s\n' 'cc --mode: --mode 는 한 번만 쓸 수 있습니다' >&2
          return 1
        fi
        saw=1
        mode="${src[i]#--mode=}"
        [ -n "$mode" ] || mode="-"
        ;;
      *)
        out+=("${src[i]}")
        ;;
    esac
    i=$((i + 1))
  done

  _cc_mode="$mode"
  _cc_applied_args=(${out[@]+"${out[@]}"})
  return 0
}

# Merge mode settings with ~/.claude/settings.local.json skillOverrides (mode wins).
# Writes a resolved file and prints its path.
_cc_resolve_mode_settings() {
  local mode_file="$1"
  local local_file="${HOME}/.claude/settings.local.json"
  local out="${TMPDIR:-/tmp}/cc-settings-${USER:-user}-${mode_file##*/}"

  if [ -f "$local_file" ]; then
    jq -n --slurpfile mode "$mode_file" --slurpfile local "$local_file" '
      ($mode[0] // {}) as $m
      | ($local[0].skillOverrides // {}) as $loc
      | $m + {skillOverrides: ($loc + ($m.skillOverrides // {}))}
      | if (.skillOverrides | length) == 0 then del(.skillOverrides) else . end
    ' > "$out" || return 1
  else
    cp "$mode_file" "$out" || return 1
  fi
  printf '%s\n' "$out"
}

_cc_inject_mode_settings() {
  local mode="$1"
  shift
  local -a src=("$@") extra=() merged=()
  local file resolved mcp a have_settings=0 have_mcp=0 inserted=0

  if ! [[ "$mode" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
    printf '%s\n' "cc --mode: 잘못된 모드 이름: ${mode}" >&2
    return 1
  fi

  file="$(_cc_mode_settings_file "$mode")"
  if [ ! -f "$file" ]; then
    printf '%s\n' "cc --mode: 설정 파일이 없습니다: ${file}" >&2
    _cc_list_modes
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1 || ! jq -e 'type == "object"' "$file" >/dev/null 2>&1; then
    printf '%s\n' "cc --mode: 잘못된 JSON: ${file}" >&2
    return 1
  fi

  for a in ${src[@]+"${src[@]}"}; do
    [ "$a" = "--" ] && break
    case "$a" in
      --settings|--settings=*) have_settings=1 ;;
      --mcp-config|--mcp-config=*) have_mcp=1 ;;
    esac
  done

  if [ "$have_settings" -eq 1 ]; then
    printf '%s\n' "cc --mode: --settings 가 이미 있어 ${file} 을 건너뜁니다" >&2
  else
    resolved="$(_cc_resolve_mode_settings "$file")" || return 1
    extra+=(--settings "$resolved")
  fi

  mcp="$(_cc_settings_dir)/mcp.${mode}.json"
  if [ -f "$mcp" ]; then
    if [ "$have_mcp" -eq 1 ]; then
      printf '%s\n' "cc --mode: --mcp-config 가 이미 있어 ${mcp} 을 건너뜁니다" >&2
    else
      extra+=(--mcp-config "$mcp")
    fi
  fi

  if [ "${#extra[@]}" -eq 0 ]; then
    _cc_applied_args=(${src[@]+"${src[@]}"})
    return 0
  fi

  # --tmux --resume 가 $1 을 보도록, wrapper 플래그 앞이 아니라 `--` 앞(없으면 끝)에 붙인다.
  for a in ${src[@]+"${src[@]}"}; do
    if [ "$inserted" -eq 0 ] && [ "$a" = "--" ]; then
      merged+=("${extra[@]}")
      inserted=1
    fi
    merged+=("$a")
  done
  [ "$inserted" -eq 1 ] || merged+=("${extra[@]}")
  _cc_applied_args=("${merged[@]}")
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
  set -- ${_cc_applied_args[@]+"${_cc_applied_args[@]}"}

  if [ "$_cc_mode" = "-" ]; then
    if [ $# -gt 0 ]; then
      printf '%s\n' 'cc --mode: 모드 이름이 필요합니다 (예: cc --mode default)' >&2
      _cc_list_modes
      return 1
    fi
    _cc_list_modes
    return
  fi

  if [ -n "$_cc_mode" ]; then
    _cc_inject_mode_settings "$_cc_mode" "$@" || return
    set -- ${_cc_applied_args[@]+"${_cc_applied_args[@]}"}
  fi

  command claude "$@"
}
claude() { cc "$@"; }
