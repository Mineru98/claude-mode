#!/bin/sh
# claude-mode installer — POSIX sh. bash / zsh 어느 쪽이든 설치된다.
#
#   curl -fsSL https://raw.githubusercontent.com/Mineru98/claude-mode/refs/heads/main/install.sh | sh
#
# 환경변수
#   CLAUDE_MODE_HOME   설치 경로 (기본 ~/.claude-mode)
#   CLAUDE_MODE_REPO   저장소 URL
#   CLAUDE_MODE_REF    branch / tag (기본 main)
#   CLAUDE_MODE_SHELL  rc 를 건드릴 셸: auto | bash | zsh | both | none (기본 auto)

set -eu

SLUG="Mineru98/claude-mode"
REPO="${CLAUDE_MODE_REPO:-https://github.com/${SLUG}.git}"
REF="${CLAUDE_MODE_REF:-main}"
DEST="${CLAUDE_MODE_HOME:-${HOME}/.claude-mode}"
TARGET_SHELL="${CLAUDE_MODE_SHELL:-auto}"

BEGIN_MARK='# >>> claude-mode >>>'
END_MARK='# <<< claude-mode <<<'

if [ -t 1 ]; then
  C_B=$(printf '\033[1m'); C_G=$(printf '\033[32m'); C_Y=$(printf '\033[33m')
  C_R=$(printf '\033[31m'); C_0=$(printf '\033[0m')
else
  C_B=''; C_G=''; C_Y=''; C_R=''; C_0=''
fi

say()  { printf '%s\n' "${C_G}==>${C_0} $*"; }
warn() { printf '%s\n' "${C_Y}warn:${C_0} $*" >&2; }
die()  { printf '%s\n' "${C_R}error:${C_0} $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- 사전 점검

[ -n "${HOME:-}" ] || die 'HOME 이 없습니다.'

os="$(uname -s 2>/dev/null || echo unknown)"

pkg_hint() {
  case "$os" in
    Darwin) printf 'brew install %s' "$1" ;;
    *)
      if have apt-get; then printf 'sudo apt-get install -y %s' "$1"
      elif have dnf;   then printf 'sudo dnf install -y %s' "$1"
      elif have pacman;then printf 'sudo pacman -S --noconfirm %s' "$1"
      elif have apk;   then printf 'sudo apk add %s' "$1"
      else printf '패키지 매니저로 %s 설치' "$1"
      fi
      ;;
  esac
}

say '필요한 것 확인'

have jq || die "jq 가 없습니다. 래퍼가 설정 파일을 합칠 때 씁니다.
    $(pkg_hint jq)"

if ! have git && ! have curl; then
  die "git 또는 curl 중 하나는 있어야 저장소를 받습니다.
    $(pkg_hint git)"
fi

if ! have bash && ! have zsh; then
  die "bash 또는 zsh 중 하나는 있어야 합니다."
fi

printf '    jq   %s\n' "$(command -v jq)"
have git  && printf '    git  %s\n' "$(command -v git)"  || true
have bash && printf '    bash %s\n' "$(command -v bash)" || true
have zsh  && printf '    zsh  %s\n' "$(command -v zsh)"  || true

if have claude; then
  printf '    claude %s\n' "$(command -v claude)"
else
  warn 'claude 가 PATH 에 없습니다. 설치는 계속하지만, 래퍼를 쓰려면 Claude Code CLI 가 필요합니다.
      https://docs.anthropic.com/en/docs/claude-code'
fi

# ---------------------------------------------------------------- 저장소 받기

fetch_tarball() {
  _tmp="$(mktemp -d)" || die 'mktemp 실패'
  _url="https://codeload.github.com/${SLUG}/tar.gz/refs/heads/${REF}"
  curl -fsSL "$_url" | tar -xzf - -C "$_tmp" \
    || { rm -rf "$_tmp"; die "다운로드 실패: $_url"; }
  _src="$(find "$_tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  [ -n "$_src" ] || { rm -rf "$_tmp"; die '압축 해제 결과가 비어 있습니다.'; }
  rm -rf "$DEST"
  mkdir -p "$(dirname "$DEST")"
  mv "$_src" "$DEST"
  rm -rf "$_tmp"
}

if [ -d "$DEST/.git" ] && have git; then
  say "업데이트: $DEST"
  git -C "$DEST" fetch --depth 1 origin "$REF" >/dev/null 2>&1 \
    || die "git fetch 실패: $REPO ($REF)"
  git -C "$DEST" checkout -q FETCH_HEAD 2>/dev/null \
    || git -C "$DEST" reset -q --hard FETCH_HEAD \
    || die 'git checkout 실패'
elif have git; then
  say "받는 중: $REPO ($REF) → $DEST"
  [ -e "$DEST" ] && rm -rf "$DEST" || true
  mkdir -p "$(dirname "$DEST")"
  git clone -q --depth 1 --branch "$REF" "$REPO" "$DEST" \
    || die "git clone 실패: $REPO ($REF)"
else
  say "받는 중(tarball): $SLUG ($REF) → $DEST"
  fetch_tarball
fi

[ -f "$DEST/claude-mode.zsh" ]  || die "설치가 이상합니다: $DEST/claude-mode.zsh 없음"
[ -f "$DEST/claude-mode.bash" ] || die "설치가 이상합니다: $DEST/claude-mode.bash 없음"
[ -d "$DEST/settings" ]         || die "설치가 이상합니다: $DEST/settings 없음"

modes=$(ls "$DEST"/settings/settings.*.json 2>/dev/null \
  | sed 's|.*/settings\.||; s|\.json$||' | tr '\n' ' ')

# ---------------------------------------------------------------- rc 블록

block() {
  cat <<BLOCK
${BEGIN_MARK}
# claude-mode — claude --mode <name>   https://github.com/${SLUG}
# 이 블록은 install.sh 가 관리합니다. 지우면 설치가 풀립니다.
# oh-my-zsh 를 쓴다면 반드시 oh-my-zsh 로드 뒤에 두세요.
export CLAUDE_MODE_HOME="${DEST}"
if [ -n "\${ZSH_VERSION-}" ] && [ -f "\$CLAUDE_MODE_HOME/claude-mode.zsh" ]; then
  . "\$CLAUDE_MODE_HOME/claude-mode.zsh"
elif [ -n "\${BASH_VERSION-}" ] && [ -f "\$CLAUDE_MODE_HOME/claude-mode.bash" ]; then
  . "\$CLAUDE_MODE_HOME/claude-mode.bash"
fi
${END_MARK}
BLOCK
}

# rc 파일에서 예전 블록을 걷어내고 새 블록을 맨 뒤에 붙인다. 여러 번 돌려도 안전하다.
rc_install() {
  rc="$1"
  if [ ! -e "$rc" ]; then
    mkdir -p "$(dirname "$rc")"
    : > "$rc"
  fi
  [ -w "$rc" ] || { warn "쓸 수 없어 건너뜁니다: $rc"; return 1; }

  if grep -qF "$BEGIN_MARK" "$rc" 2>/dev/null; then
    action='갱신'
  else
    action='추가'
    cp "$rc" "${rc}.claude-mode.bak" 2>/dev/null || true
  fi

  stripped="$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
      $0 == b { skip = 1 }
      skip != 1 { print }
      $0 == e { skip = 0 }
    ' "$rc")"

  {
    [ -n "$stripped" ] && printf '%s\n\n' "$stripped" || true
    block
  } > "${rc}.claude-mode.tmp" || { warn "쓰기 실패: $rc"; return 1; }
  mv "${rc}.claude-mode.tmp" "$rc"

  say "$action: $rc"
  RC_TOUCHED="${RC_TOUCHED} ${rc}"
  return 0
}

zsh_rc()  { printf '%s\n' "${ZDOTDIR:-$HOME}/.zshrc"; }
bash_rc() { printf '%s\n' "${HOME}/.bashrc"; }

want_zsh=0
want_bash=0
case "$TARGET_SHELL" in
  none) ;;
  zsh)  want_zsh=1 ;;
  bash) want_bash=1 ;;
  both) want_zsh=1; want_bash=1 ;;
  auto)
    # 로그인 셸을 우선하고, 다른 셸도 rc 가 이미 있으면 같이 넣는다.
    case "${SHELL:-}" in
      */zsh)  want_zsh=1 ;;
      */bash) want_bash=1 ;;
    esac
    { [ -f "$(zsh_rc)" ]  && have zsh;  } && want_zsh=1  || true
    { [ -f "$(bash_rc)" ] && have bash; } && want_bash=1 || true
    if [ "$want_zsh" -eq 0 ] && [ "$want_bash" -eq 0 ]; then
      if have bash; then want_bash=1; else want_zsh=1; fi
    fi
    ;;
  *) die "CLAUDE_MODE_SHELL 값이 이상합니다: $TARGET_SHELL (auto|bash|zsh|both|none)" ;;
esac

RC_TOUCHED=''

[ "$want_zsh" -eq 1 ]  && rc_install "$(zsh_rc)"  || true
[ "$want_bash" -eq 1 ] && rc_install "$(bash_rc)" || true

# macOS 의 bash 로그인 셸은 .bashrc 를 안 읽는 경우가 많다. .bash_profile 도 챙긴다.
if [ "$want_bash" -eq 1 ] && [ "$os" = 'Darwin' ]; then
  bp="${HOME}/.bash_profile"
  if [ -f "$bp" ] && ! grep -q 'bashrc' "$bp"; then
    rc_install "$bp" || true
  fi
fi

if [ "$TARGET_SHELL" = 'none' ] || [ -z "$RC_TOUCHED" ]; then
  warn 'rc 파일은 건드리지 않았습니다. 아래 블록을 직접 넣으세요.'
  printf '\n'
  block
  printf '\n'
fi

# ---------------------------------------------------------------- 마무리

printf '\n%s\n' "${C_B}claude-mode 설치 완료${C_0}"
printf '  경로   %s\n' "$DEST"
printf '  모드   %s\n' "$modes"
printf '\n다음 단계\n'
reload=''
for f in $RC_TOUCHED; do reload="${reload} . ${f}"; done
if [ -n "$reload" ]; then
  printf '  1. 새 터미널 탭을 엽니다 (또는%s).\n' "$reload"
else
  printf '  1. 위 블록을 rc 파일에 넣고 새 터미널 탭을 엽니다.\n'
fi
printf '  2. %s 로 모드 목록을 확인합니다.\n' 'claude --mode'
printf '  3. %s 처럼 씁니다.\n' 'claude --mode frontend'
printf '\n빼려면 rc 파일의 %s ~ %s 블록을 지우고 %s 를 삭제합니다.\n' \
  "$BEGIN_MARK" "$END_MARK" "$DEST"
