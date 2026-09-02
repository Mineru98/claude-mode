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

_CLAUDE_MODE_HOME="${${(%):-%x}:A:h}"

_cc_settings_dir() {
  print -r -- "${_CLAUDE_MODE_HOME}/settings"
}

_cc_mode_settings_file() {
  print -r -- "$(_cc_settings_dir)/settings.${1}.json"
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
