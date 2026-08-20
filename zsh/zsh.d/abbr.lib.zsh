# abbrevation implementation for zsh
# A simpler and better alternative to olets/zsh-abbr,
# but with my own full control and better integration with other plugins.
#
# abbrevation definitions live in ./alias.zsh
typeset -gA abbrevs
abbrevs=()

# zabbr() {{{
# Usage:
#   zabbr key='expansion' [key2='expansion2' ...]   # define abbreviation(s)
#   zabbr key                                       # print the definition of `key`
#   zabbr                                           # print all definitions
function zabbr() {
  emulate -L zsh
  local arg key
  if (( $# == 0 )); then
    for key in ${(ko)abbrevs}; do
      print -r -- "zabbr ${(q-)key}=${(qq)abbrevs[$key]}"
    done
    return 0
  fi
  for arg in "$@"; do
    if [[ $arg != *=* ]]; then
      # no '=': treat as a query
      if [[ -z ${abbrevs[$arg]} ]]; then
        print -ru2 -- "zabbr: no such abbreviation: $arg"
        return 1
      fi
      print -r -- "zabbr ${(q-)arg}=${(qq)abbrevs[$arg]}"
      continue
    fi
    key=${arg%%=*}
    if [[ -z $key ]]; then
      print -ru2 -- "zabbr: invalid argument: $arg"
      return 1
    fi
    abbrevs[$key]=${arg#*=}
  done
}

# ---------------------------------------------------------------- }}}
# zsh bindings and ZLE widgets {{{

# Tokens after which the next word is again in command position:
# command separators and openers, keywords that introduce a command, and precommands
# (e.g. `sudo g` should expand, but `alias g` must not).
typeset -ga ABBR_COMMAND_PREFIXES=(
  '&' '&&' '|' '||' '|&' ';' ';;' '(' '((' '$(' '`' '{' '!'
  if then elif else while until do repeat time coproc
  sudo doas command builtin exec nohup env xargs noglob nocorrect stdbuf
)

# Do the given tokens (those preceding the abbreviation) end at a command position?
abbrev-command-position() {
  emulate -L zsh
  setopt local_options extended_glob
  (( $# )) || return 0                   # nothing before it: start of the line
  local last=$@[-1]
  # (Ie) => exact string match; `(` and `|` would be glob patterns otherwise
  (( ${ABBR_COMMAND_PREFIXES[(Ie)$last]} )) && return 0
  [[ $last == [[:alpha:]_][[:alnum:]_]#=* ]] && return 0   # `FOO=bar gs`
  return 1
}

abbrev-expand() {
  emulate -L zsh
  [[ -z $LBUFFER ]] && return 1
  # The cursor may sit right after a just-closed command substitution or subshell;
  # e.g., `gs`, $(gs), (gs). So we should look at the word before that.
  local closers=${LBUFFER##*[^\)\`]}
  local head=${LBUFFER[1,${#LBUFFER} - ${#closers}]}
  # only the word being typed can be an abbreviation
  [[ -z $head || $head == *[[:space:]] ]] && return 1

  # ${(z)...} splits the buffer the way the shell parser does (and turns a newline into `;`),
  # but keeps an unterminated `$(` or backtick together with all that follows it,
  # so we narrow down to the innermost open substitution.
  local inner=${${head##*\$\(}##*\`}
  local -a tokens=( ${(z)inner} )

  # Candidates for the abbreviation, most specific first: the raw word,
  # because a name may contain shell punctuation (`ez;`, `r!`), then the last parsed token.
  # This separates `gs` out of `x;gs` or `$(gs`, for example.
  local word expansion
  local -a before candidates=( ${inner##*[[:space:]]} $tokens[-1] )
  local -i cut
  for word in ${(u)candidates}; do
    expansion=${abbrevs[$word]}
    [[ -n $expansion ]] || continue
    # only expand in command position, so that e.g. `alias g` stays as typed
    (( cut = ${#inner} - ${#word} ))
    before=( ${(z)${inner[1,cut]}} )
    abbrev-command-position $before || continue
    # splice the expansion over the abbreviation, keeping any closers after it
    LBUFFER[-$(( ${#word} + ${#closers} )),-$(( ${#closers} + 1 ))]=$expansion
    return 0
  done
  return 1
}

# On <space>: expand an abbreviation, or fall back to the built-in magic-space
# (i.e. perform history expansion) when there is nothing to expand.
abbrev-space()  { if abbrev-expand; then zle self-insert; else zle magic-space; fi }
# On <CR>: expand on accept as well
abbrev-accept() { abbrev-expand; zle accept-line }
zle -N abbrev-space
zle -N abbrev-accept
bindkey ' '            abbrev-space
bindkey '^M'           abbrev-accept
# note: <Tab> is not bound here; expansion on <Tab> is a completer, see below.

# ---------------------------------------------------------------- }}}
# Tab completion {{{

# Complete abbreviations in the command position, the way aliases are completed
# (e.g. `g<Tab>` offers `gs`, `gco`, ...). Reads $abbrevs lazily, so ones
# defined later (or interactively) are picked up as well.
_zabbr_names() {
  local -a abbrs
  local key word=$IPREFIX$PREFIX$SUFFIX$ISUFFIX
  for key in ${(k)abbrevs}; do
    # an exact hit is not a completion but an expansion; leave it to _expand_abbr
    [[ $key == $word ]] && continue
    abbrs+=( "${key}:${abbrevs[$key]}" )
  done
  _describe -t abbreviations 'abbreviation' abbrs
}

# Expand an abbreviation on <Tab>, the way zsh expands an alias (`ZQ<Tab>` => `exit`).
# This is a completer rather than a key binding: <Tab> is contended (fzf-widgets.zsh, fzf-tab, ...),
# whereas the completer chain is an ordered list made for exactly this.
# Returning 1 lets the next completer in the chain run, as _expand_alias does.
_expand_abbr() {
  local word=$IPREFIX$PREFIX$SUFFIX$ISUFFIX
  [[ -n ${abbrevs[$word]} ]] || return 1
  abbrev-command-position $words[1,CURRENT-1] || return 1
  local expl
  _wanted abbreviations expl abbreviation compadd -UQ -- "${abbrevs[$word]}"
}

# Register it *after* _complete/_match rather than in front of them:
# _main_complete stops at the first completer that produces matches,
# so expansion only happens when there is nothing left to complete.
# (Example) `g<Tab>` => lists `gs`, `gco`, `git`, ...,
#     while `ZQ<Tab>`, which nothing else matches, expands to `exit`.
() {
  local -a completers
  zstyle -a ':completion:*' completer completers || completers=( _complete )
  (( ${completers[(Ie)_expand_abbr]} )) && return
  local -i i=${completers[(Ie)_match]}
  (( i )) || i=${completers[(Ie)_complete]}
  (( i )) || i=$#completers
  zstyle ':completion:*' completer $completers[1,i] _expand_abbr $completers[i+1,-1]
}

# `-command-` is the completion "service" for the command word.
# Wrap whatever is currently registered (usually _autocd) rather than replacing it.
if (( $+functions[compdef] )) && [[ $_comps[-command-] != _zabbr_command_names ]]; then
  typeset -g _zabbr_orig_command_names=${_comps[-command-]:-"_command_names -e"}
  _zabbr_command_names() {
    _zabbr_names
    eval $_zabbr_orig_command_names
  }
  compdef _zabbr_command_names -command-
fi

# ---------------------------------------------------------------- }}}
# Syntax highlighting (F-Sy-H) {{{

# Problem: F-Sy-H resolves the command word against $aliases, $functions, $commands, ...
# abbreviations are in none of those, so they would be highlighted red as unknown commands
# (before expansion).
# Solution: Report them as aliases instead -- which is what they are, near enough.
# There is no supported hook for this, so we wrap the function, but degrade to the default
# stock behavior rather than breaking the prompt if it ever goes away.
if (( $+functions[-fast-highlight-main-type] && ! $+functions[-fast-highlight-main-type-orig] )); then
  functions[-fast-highlight-main-type-orig]=$functions[-fast-highlight-main-type]
  -fast-highlight-main-type() {
    if (( $+abbrevs[$1] )); then
      REPLY=alias
    else
      -fast-highlight-main-type-orig "$@"
    fi
  }
fi

# ---------------------------------------------------------------- }}}
# Integration with zsh-autosuggestions {{{

# zsh-autosuggestions (re-)wraps all ZLE widgets on precmd, i.e. after this file is sourced.
# Widgets it doesn't know are assumed to modify the buffer, so `abbrev-accept` would
# get the "modify" action: it re-fetches a suggestion and re-sets POSTDISPLAY *after* accept-line,
# leaving the grey suggestion text printed on the accepted line as if it had been accepted.
# Ask for "clear".
typeset -ga ZSH_AUTOSUGGEST_CLEAR_WIDGETS
(( ${ZSH_AUTOSUGGEST_CLEAR_WIDGETS[(I)abbrev-accept]} )) || \
  ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=( abbrev-accept )

# ---------------------------------------------------------------- }}}

# vim: set foldmethod=marker:
