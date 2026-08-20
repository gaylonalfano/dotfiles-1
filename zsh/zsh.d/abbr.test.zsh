#!/usr/bin/env zsh
# Tests for ./abbr.lib.zsh: the zabbr command, space widget fallback,
# completion hookup, F-Sy-H main-type wrapper, and zsh-autosuggestions binding.
# Widgets are exercised as plain functions with `zle` stubbed out, so no pty is needed.
#
# Run:  zsh -f zsh/zsh.d/abbr.test.zsh   (exit code 0 = all assertions passed)

emulate -R zsh
typeset -gA __fast_highlight_main__command_type_cache

LIB=${0:A:h}/abbr.lib.zsh
FSYH=~/.dotfiles/zsh/antidote-plugins/wookayin/fast-syntax-highlighting
AUTOSUGGEST=~/.dotfiles/zsh/antidote-plugins/zsh-users/zsh-autosuggestions/zsh-autosuggestions.zsh

# ---------------------------------------------------------------- assertions

typeset -gi TESTS=0 FAILURES=0
autoload -Uz colors && colors

section() { print; print "=== $* ===" }
assert_eq() {  # assert_eq <description> <expected> <actual>
  local desc=$1 expected=$2 actual=$3
  (( TESTS++ ))
  if [[ $expected == "$actual" ]]; then    # note: RHS must be quoted (no globbing)
    print "  ${fg[green]}ok${reset_color}   $desc"
  else
    (( FAILURES++ ))
    print "  ${fg[red]}FAIL${reset_color} $desc"
    print "         expected: ${(qq)expected}"
    print "         actual:   ${(qq)actual}"
  fi
}

# ---------------------------------------------------------------- 1. zabbr

section "1. zabbr: define / query / list"
source $LIB   # NOTE: must not be piped -- that would source it in a subshell

zabbr gs='git status' c='command -v'
zabbr 'r!'='exec zsh --login'
zabbr 'x=foo=bar'         # only the first '=' separates key and expansion
assert_eq "define: gs"            'git status'        "$abbrevs[gs]"
assert_eq "define: c"             'command -v'        "$abbrevs[c]"
assert_eq "define: r! (bang key)" 'exec zsh --login'  "$abbrevs[r!]"
assert_eq "define: '=' in value"  'foo=bar'           "$abbrevs[x]"

assert_eq "query: zabbr gs"  "zabbr gs='git status'"  "$(zabbr gs)"
expected_list=(
  "zabbr c='command -v'"
  "zabbr gs='git status'"
  "zabbr r!='exec zsh --login'"
  "zabbr x='foo=bar'"
)
assert_eq "list: zabbr (sorted)"  ${(F)expected_list}  "$(zabbr)"

assert_eq "error: unknown key (stderr)" \
  'zabbr: no such abbreviation: nope'  "$(zabbr nope 2>&1)"
zabbr nope 2>/dev/null
assert_eq "error: unknown key (status)"  1  $?
zabbr '=bad' 2>/dev/null
assert_eq "error: empty key (status)"    1  $?

# ---------------------------------------------------------------- 2. widgets

section "2. space widget: expansion vs magic-space fallback"
# stub zle: record which widget was invoked, and emulate its buffer effect
typeset -g LAST_WIDGET=
zle() {
  LAST_WIDGET=$1
  case $1 in
    self-insert|magic-space) LBUFFER+=' ' ;;
  esac
}
try_space() {  # try_space <buffer> <expected widget> <expected buffer>
  LBUFFER=$1; LAST_WIDGET=
  abbrev-space
  assert_eq "${(qq)1} -> $2" "$2|$3" "$LAST_WIDGET|$LBUFFER"
}
zabbr g='git' 'ez;'='exec zsh --login'
try_space 'gs'       self-insert 'git status '
try_space 'c'        self-insert 'command -v '
try_space 'g'        self-insert 'git '
try_space 'foo'      magic-space 'foo '
try_space '!!'       magic-space '!! '
try_space 'echo hi'  magic-space 'echo hi '
try_space ''         magic-space ' '

section "2b. word boundaries other than whitespace"
try_space 'echo $(gs'     self-insert 'echo $(git status '
try_space '$(gs'          self-insert '$(git status '
try_space '`gs'           self-insert '`git status '
try_space '(gs'           self-insert '(git status '
try_space '{gs'           self-insert '{git status '
try_space 'x | gs'        self-insert 'x | git status '
try_space 'x|gs'          self-insert 'x|git status '
try_space 'x && gs'       self-insert 'x && git status '
try_space 'x; gs'         self-insert 'x; git status '
try_space 'echo $(ls; gs' self-insert 'echo $(ls; git status '
# `!` is part of an abbreviation name, so it must not split words
try_space 'r!'            self-insert 'exec zsh --login '
try_space 'echo $(r!'     self-insert 'echo $(exec zsh --login '
# ... and neither may `;` when the name itself contains it (`zabbr 'ez;'=...`)
try_space 'ez;'           self-insert 'exec zsh --login '
try_space 'ls; ez;'       self-insert 'ls; exec zsh --login '
try_space '$(ez;'         self-insert '$(exec zsh --login '
try_space 'echo ez;'      magic-space 'echo ez; '
# the plain-token path still works when the raw word is not an abbreviation
try_space 'x;gs'          self-insert 'x;git status '
try_space 'x!gs'          magic-space 'x!gs '
# no partial matches
try_space 'gsx'           magic-space 'gsx '
try_space 'gg'            magic-space 'gg '
# the word must be the one being typed, and quoting/escaping makes it a
# different word (${(z)} parses these the way the shell does)
try_space 'gs '           magic-space 'gs  '
try_space 'echo\ gs'      magic-space 'echo\ gs '
try_space '"gs'           magic-space '"gs '
try_space "'gs"           magic-space "'gs "

section "2b'. cursor right after a closed substitution / subshell"
try_space '`gs`'          self-insert '`git status` '
try_space '$(gs)'         self-insert '$(git status) '
try_space '(gs)'          self-insert '(git status) '
try_space 'echo $(gs)'    self-insert 'echo $(git status) '
try_space '$(ls; gs)'     self-insert '$(ls; git status) '
try_space 'x=$(gs)'       self-insert 'x=$(git status) '
try_space '$(echo $(gs))' self-insert '$(echo $(git status)) '
# still not a command position inside the substitution
try_space '$(echo gs)'    magic-space '$(echo gs) '
try_space '`ls gs`'       magic-space '`ls gs` '
# a closing paren that is not a substitution
try_space 'echo (a|b)'    magic-space 'echo (a|b) '

section "2c. only in command position"
# not a command position: an argument of another command
try_space 'alias g'       magic-space 'alias g '
try_space 'ls gs'         magic-space 'ls gs '
try_space 'which g'       magic-space 'which g '
try_space 'echo -n gs'    magic-space 'echo -n gs '
try_space 'ls > gs'       magic-space 'ls > gs '
try_space 'ls >gs'        magic-space 'ls >gs '
try_space 'git g'         magic-space 'git g '
# command position: after separators, keywords, precommands and assignments
try_space 'sudo gs'       self-insert 'sudo git status '
try_space 'command gs'    self-insert 'command git status '
try_space 'if gs'         self-insert 'if git status '
try_space 'while gs'      self-insert 'while git status '
try_space 'ls; gs'        self-insert 'ls; git status '
try_space 'ls && gs'      self-insert 'ls && git status '
try_space 'ls | gs'       self-insert 'ls | git status '
try_space '! gs'          self-insert '! git status '
try_space 'FOO=bar gs'    self-insert 'FOO=bar git status '
try_space $'ls\ngs'       self-insert $'ls\ngit status '

section "3. accept widget"
try_accept() {  # try_accept <buffer> <expected buffer>
  LBUFFER=$1; LAST_WIDGET=
  abbrev-accept
  assert_eq "${(qq)1} -> ${(qq)2}" "accept-line|$2" "$LAST_WIDGET|$LBUFFER"
}
try_accept 'gs'          'git status'
try_accept 'echo $(gs'   'echo $(git status'
try_accept 'echo $(gs)'  'echo $(git status)'
try_accept '`gs`'        '`git status`'
try_accept 'foo'         'foo'

section "3b. <Tab> expansion (the _expand_abbr completer)"
# _expand_abbr runs inside the completion system; stub out the bits it uses so
# it can be called directly: what it would compadd, and its return status.
typeset -g COMPADDED=
_wanted() { shift 3; "$@" }        # _wanted <tag> <expl-var> <descr> <cmd...>
compadd() { COMPADDED=$@[-1] }
try_complete() {  # try_complete <words...> <expected compadd, or '' for "not handled">
  local expected=$@[-1]
  local -a words=( ${@[1,-2]} )
  local CURRENT=$#words IPREFIX= ISUFFIX= SUFFIX= PREFIX=$words[-1]
  local -i expected_ret=1
  [[ -n $expected ]] && expected_ret=0
  COMPADDED=
  _expand_abbr
  assert_eq "${(j: :)words} -> ${expected:-<next completer>}" \
    "$expected|$expected_ret" "$COMPADDED|$?"
}
# an abbreviation in command position expands, as an alias would
try_complete gs                  'git status'
try_complete 'r!'                'exec zsh --login'
try_complete sudo gs             'git status'
try_complete 'FOO=bar' gs        'git status'
# everything else returns 1, so the next completer in the chain runs
try_complete gsx                 ''
try_complete alias g             ''
try_complete ls gs               ''
try_complete git g               ''

section "3c. completer chain registration"
# _expand_abbr must sit right after _complete/_match, so that it only runs when
# nothing else completed the word (`g<Tab>` keeps listing `g*`).
() {
  local -a chain
  # a chain like prezto's, to be sure the insert lands in the middle
  zstyle ':completion:*' completer _complete _match _approximate
  source $LIB
  zstyle -a ':completion:*' completer chain
  assert_eq "inserted after _complete/_match"  '_complete _match _expand_abbr _approximate' \
    "${chain[*]}"
  # with no _complete/_match in the chain it goes last
  zstyle ':completion:*' completer _oldlist _list
  source $LIB
  zstyle -a ':completion:*' completer chain
  assert_eq "appended when no _complete"  '_oldlist _list _expand_abbr'  "${chain[*]}"

  zstyle ':completion:*' completer _complete
  source $LIB
  zstyle -a ':completion:*' completer chain
  assert_eq "existing chain kept"    _complete     "$chain[1]"
  source $LIB   # re-sourcing must not add it twice
  zstyle -a ':completion:*' completer chain
  local -a matched=( ${(M)chain:#_expand_abbr} )
  assert_eq "registration is idempotent"  1  $#matched
}

# ---------------------------------------------------------- 4. completion

section "4. tab completion hookup"
autoload -Uz compinit && compinit -u -d /tmp/.zcompdump-abbrtest >/dev/null 2>&1
# compinit registers -command- only now, so re-source to exercise the compdef branch
source $LIB
zabbr gs='git status' c='command -v'
assert_eq "-command- is wrapped"      '_zabbr_command_names'  "$_comps[-command-]"
assert_eq "original service is kept"  '_autocd'               "$_zabbr_orig_command_names"
assert_eq "_zabbr_names is defined"   1                       "$+functions[_zabbr_names]"

# `gs<Tab>` must still offer `gsu`, `gst`, ... but not `gs` itself: an exact hit
# is an expansion (_expand_abbr), not a completion.
zabbr gsu='git status -u' gst='git stash'
_describe() { REPLY_NAMES=( ${${(@P)${@[-1]}}%%:*} ) }   # _describe -t <tag> <descr> <array-name>
() {
  local IPREFIX= ISUFFIX= SUFFIX= PREFIX=gs
  local -a REPLY_NAMES matched
  _zabbr_names
  # note: ${(M)array:#pat} only filters element-wise in a plain array assignment;
  # inside quotes or nested in another ${...} the array is joined first
  matched=( ${(M)REPLY_NAMES:#gs} )
  assert_eq "exact match is excluded"  0  $#matched
  matched=( ${(M)REPLY_NAMES:#gs*} )
  assert_eq "other names are offered"  'gst gsu'  "${(on)matched}"
}

# ------------------------------------------------------- 5. F-Sy-H wrapper

section "5. F-Sy-H command-type wrapper"
typeset -g FAST_BASE_DIR=$FSYH
typeset -gA FAST_HIGHLIGHT_STYLES
source $FSYH/fast-highlight
assert_eq "stock main-type is loaded" 1 "$+functions[-fast-highlight-main-type]"
source $LIB   # must wrap it, as zshrc sources zsh.d/* after the plugins
zabbr gs='git status' 'r!'='exec zsh --login'
main_type() { REPLY=; -fast-highlight-main-type "$1"; print -r -- $REPLY }
assert_eq "abbreviation -> alias"      alias    "$(main_type gs)"
assert_eq "bang name -> alias"         alias    "$(main_type 'r!')"
assert_eq "real command -> command"    command  "$(main_type ls)"
assert_eq "unknown -> none"            none     "$(main_type definitely-not-a-command)"
assert_eq "glob-ish word -> none"      none     "$(main_type 'x[y')"

# -------------------------------------------------- 6. zsh-autosuggestions

section "6. zsh-autosuggestions binding"
# fresh subshell: the plugin must be loaded *before* abbr.lib.zsh, as in zshrc.
# Assertion counts are reported back through the exit status.
() {
  ( unfunction zle main_type 2>/dev/null
    TESTS=0 FAILURES=0
    source $AUTOSUGGEST
    source $LIB
    source $LIB          # sourcing twice must not duplicate the entry
    _zsh_autosuggest_start   # what precmd does
    local -a matched=( ${(M)ZSH_AUTOSUGGEST_CLEAR_WIDGETS:#abbrev-accept} )
    assert_eq "registered once in CLEAR_WIDGETS" 1 $#matched
    local w action
    local -A expected_action=( abbrev-accept clear  abbrev-space modify )
    for w in abbrev-accept abbrev-space; do
      # 2nd line of the bound widget is `_zsh_autosuggest_widget_<action> ...`
      action=${${(z)${(f)"$(functions ${widgets[$w]#user:})"}[2]}[1]}
      assert_eq "$w action" "_zsh_autosuggest_widget_$expected_action[$w]" $action
    done
    exit $(( (TESTS * 256) + FAILURES ))
  )
  local -i rc=$?
  (( TESTS += rc / 256, FAILURES += rc % 256 ))
}

# ---------------------------------------------------------------- summary

print
if (( FAILURES )); then
  print "${fg[red]}FAILED${reset_color}: $FAILURES of $TESTS assertions failed"
else
  print "${fg[green]}PASSED${reset_color}: all $TESTS assertions passed"
fi
exit $(( FAILURES > 0 ))
