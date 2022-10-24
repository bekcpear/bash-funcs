#
# **BEGIN**
# BASHFUNC02: _opts
#
#  Author: Ryan Qian <i@bitbili.net>
# License: GPL-2
#
# Handle script options by Linux version 'getopt',
# it also print it's own help messages, and export a
# function '_bashfunc_help' for later use.
#
# This file contains a preprocess function to add options
# and descriptions, each function call add one option record,
#
# function:
#   _opts_add [-o <name>] [-l <name>] [-v [o]] [-t <type>] [-d <value>] [-i <description>]
#     -o <name>         specify short option name (-), one character
#     -l <name>         specify long option name (--), two or more characters
#     -v [o]            specify this option has a value, 'o' marks this value is optional
#     -t <type-desc>    specify the type if this has a value
#     -d <value>        specify the default value if this has a value
#     -i <description>  specify the description of this option
#
# and a handle function to handle options,
#
# function:
#   _opts_handle "${@}"
#     should always pass the all arguments to it unless there are special circumstances,
#     please note the double quotation marks are necessary.
#     This function does a lot of things, includes make the variable which called within the
#     _bashfunc_help function, and make all variables which represent added options:
#
#       _opts_s_tigger_<short-opt-name> for each tiggered short opt name
#       _opts_l_tigger_<long-opt-name>  for each tiggered long opt name
#
#       _opts_s_value_<short-opt-name>  to store the value of each tiggered short opt
#       _opts_l_value_<long-opt-name>   to store the value of each tiggered long opt
#
#       _opts_remaining                 array to store all unparsed arguments
#
#     you can use these variables to do do further processings
#
# you can also specify a description to describe the script by
#
# variable:
#   _BASHFUNC_OPTS_NAME <STRING>
# default:
#   $(basename $0)
#
# variable:
#   _BASHFUNC_OPTS_USAGE <STRING>
# default:
#   {options}
#
# variable:
#   _BASHFUNC_OPTS_DESC <STRING>
# default:
#   <UNSET>
#
# example:
#   . /path/to/_opts.sh
#   _opts_add -o a -l abc -v -t string -d test -i "some descriptions"$'\n'"some descriptions"
#   _opts_add -o b -l bbc -v o -t string -d test -i "some descriptions"$'\n'"some descriptions"
#   _opts_add -o c -l cbc -i "some descriptions"$'\n'"some descriptions"
#   ...
#   _BASHFUNC_OPTS_NAME="test"
#   _BASHFUNC_OPTS_USAGE="{options} other-args"
#   _BASHFUNC_OPTS_DESC="some descriptions"$'\n'"some descriptions"
#   _opts_handle "${@}"
#   if [[ -n _opt_s_tigger_a ]]; then
#     ...
#   fi
#   ...
#
declare -i __BASHFUNC_OPTS_INDEX=0
declare -a __BASHFUNC_OPTS_SHORT \
           __BASHFUNC_OPTS_LONG \
           __BASHFUNC_OPTS_TYPE \
           __BASHFUNC_OPTS_DESC \
           __BASHFUNC_OPTS_VALUE \
           __BASHFUNC_OPTS_DEFAULT

_opts_add() {
  local short long type has_value opt_value default desc
  while [[ -n $1 ]]; do
    case $1 in
      -o)
        shift
        short="$1"
        shift
        ;;
      -l)
        shift
        long="$1"
        shift
        ;;
      -v)
        shift
        if [[ "$1" == "o" ]]; then
          opt_value=1
          shift
        else
          has_value=1
        fi
        ;;
      -t)
        shift
        type="$1"
        shift
        ;;
      -d)
        shift
        default="$1"
        shift
        ;;
      -i)
        shift
        desc="$1"
        shift
        ;;
      *)
        echo "internal function error: _opts_add, unexpected argument '$1'" >&2
        return 1
        ;;
    esac
  done

  __BASHFUNC_OPTS_SHORT[${__BASHFUNC_OPTS_INDEX}]=${short}
  __BASHFUNC_OPTS_LONG[${__BASHFUNC_OPTS_INDEX}]=${long}
  __BASHFUNC_OPTS_TYPE[${__BASHFUNC_OPTS_INDEX}]=${type}
  __BASHFUNC_OPTS_DEFAULT[${__BASHFUNC_OPTS_INDEX}]=${default}
  __BASHFUNC_OPTS_DESC[${__BASHFUNC_OPTS_INDEX}]=${desc}
  if [[ -n ${has_value} ]]; then
    __BASHFUNC_OPTS_VALUE[${__BASHFUNC_OPTS_INDEX}]="has"
  elif [[ -n ${opt_value} ]]; then
    __BASHFUNC_OPTS_VALUE[${__BASHFUNC_OPTS_INDEX}]="opt"
  else
    __BASHFUNC_OPTS_VALUE[${__BASHFUNC_OPTS_INDEX}]="none"
  fi

  if [[ -n ${short} ]] || [[ -n ${long} ]]; then
    if [[ ( -z ${has_value} && -z ${opt_value} ) || \
          ( ${__BASHFUNC_OPTS_VALUE[${__BASHFUNC_OPTS_INDEX}]} != "none" && -n ${type} ) ]]; then
      __BASHFUNC_OPTS_INDEX=$(( ${__BASHFUNC_OPTS_INDEX} + 1 ))
    fi
  fi
}

__opts_make_short() {
  local i short=
  for (( i = 0; i < ${__BASHFUNC_OPTS_INDEX}; i++ )); do
    if [[ -n ${__BASHFUNC_OPTS_SHORT[${i}]} ]]; then
      short+=${__BASHFUNC_OPTS_SHORT[${i}]}
      if [[ ${__BASHFUNC_OPTS_VALUE[${i}]} == "has" ]]; then
        short+=":"
      elif [[ ${__BASHFUNC_OPTS_VALUE[${i}]} == "opt" ]]; then
        short+="::"
      fi
    fi
  done
  echo -n ${short}
}
__opts_make_long() {
  local i long=
  for (( i = 0; i < ${__BASHFUNC_OPTS_INDEX}; i++ )); do
    if [[ -n ${__BASHFUNC_OPTS_LONG[${i}]} ]]; then
      long+=${__BASHFUNC_OPTS_LONG[${i}]}
      if [[ ${__BASHFUNC_OPTS_VALUE[${i}]} == "has" ]]; then
        long+=":"
      elif [[ ${__BASHFUNC_OPTS_VALUE[${i}]} == "opt" ]]; then
        long+="::"
      fi
      long+=","
    fi
  done
  echo -n ${long%,}
}

__BASHFUNC_OPTS_OPTDESC=""
_bashfunc_help() {
  echo "
Usage: ${_BASHFUNC_OPTS_NAME} ${_BASHFUNC_OPTS_USAGE:-{options}}
"
  while read line; do
    if [[ ${line} =~ ^[[:space:]]*$ ]]; then
      continue
    fi
    echo "  ${line}"
  done <<<"${_BASHFUNC_OPTS_DESC}"
echo "${_BASHFUNC_OPTS_DESC:+}
${__BASHFUNC_OPTS_OPTDESC}
"
}

declare -A __BASHFUNC_OPTS_VALUE_R
__opts_make_help() {
  local i s l t v d ot lt sep= default left maxlen=0
  local -a lefts rights
  for (( i = 0; i < ${__BASHFUNC_OPTS_INDEX}; i++ )); do
    s="${__BASHFUNC_OPTS_SHORT[${i}]}"
    l="${__BASHFUNC_OPTS_LONG[${i}]}"
    t="${__BASHFUNC_OPTS_TYPE[${i}]}"
    v="${__BASHFUNC_OPTS_VALUE[${i}]}"
    d="${__BASHFUNC_OPTS_DESC[${i}]}"
    default=${__BASHFUNC_OPTS_DEFAULT[${i}]}
    if [[ ${v} == "none" ]]; then
      unset t default ot lt
    elif [[ ${v} == "opt" ]]; then
      ot=${s:+[<${t}>]}
      lt=${l:+[=<${t}>]}
      __BASHFUNC_OPTS_VALUE_R[${s:-__empty}]=1
      __BASHFUNC_OPTS_VALUE_R[${l:-__empty}]=1
    elif [[ ${v} == "has" ]]; then
      ot=${s:+ <${t}>}
      lt=${l:+ <${t}>}
      __BASHFUNC_OPTS_VALUE_R[${s:-__empty}]=1
      __BASHFUNC_OPTS_VALUE_R[${l:-__empty}]=1
    fi
    s=${s:+-${s}}
    l=${l:+--${l}}
    sep=
    if [[ -n ${s} ]] && [[ -n ${l} ]]; then
      sep=', '
    fi
    left="${s}${ot}${sep}${l}${lt}"
    if [[ ${#left} -gt ${maxlen} ]]; then
      maxlen=${#left}
    fi
    lefts+=("${left}")
    rights+=("${d}${default:+$'\n'Default: }${default}")
  done

  local placeholder=
  for (( i = 0; i < ${maxlen}; i++ )); do
    placeholder+=' '
  done

  for (( i = 0; i < ${#lefts[@]}; i++ )); do
    __BASHFUNC_OPTS_OPTDESC+='    '
    __BASHFUNC_OPTS_OPTDESC+="${lefts[${i}]}"
    __BASHFUNC_OPTS_OPTDESC+="${placeholder:${#lefts[${i}]}}"
    __BASHFUNC_OPTS_OPTDESC+='    '
    local __is_first_right_line=1
    while read line; do
      if [[ -n ${__is_first_right_line} ]]; then
        __BASHFUNC_OPTS_OPTDESC+="${line}"$'\n'
        unset __is_first_right_line
      else
        __BASHFUNC_OPTS_OPTDESC+="    ${placeholder}     ${line}"$'\n'
      fi
    done <<<"${rights[${i}]}"
  done
}

declare -a _opts_remaining
_opts_handle() {
  local _errexit=$(set +o | grep errexit)
  set +e
  unset GETOPT_COMPATIBLE

  getopt -T
  if [[ $? != 4 ]]; then
    echo "internal function error: _opts_handle, 'getopt' is not a Linux version." >&2
    return 1
  fi

  local short=$(__opts_make_short)
  local long=$(__opts_make_long)
  __opts_make_help

  : ${_BASHFUNC_OPTS_NAME:=$(basename $0)}
  local args
  args=$(getopt -o ${short} -l ${long} -n ${_BASHFUNC_OPTS_NAME} -- "$@")
  if [[ $? != 0 ]]; then
    _bashfunc_help
    return 1
  fi
  eval "${_errexit}"

  local this_arg to_store_value_s to_store_value_l is_remaining
  eval "set -- ${args}"
  for arg in "${@}"; do
    if [[ -n ${is_remaining} ]]; then
      _opts_remaining+=("${arg}")
      continue
    fi

    if [[ -n ${to_store_value_s} ]]; then
      eval "_opts_s_value_${to_store_value_s}=\${arg}"
      to_store_value_s=
      continue
    elif [[ -n ${to_store_value_l} ]]; then
      eval "_opts_l_value_${to_store_value_l}=\${arg}"
      to_store_value_l=
      continue
    fi

    if [[ ${arg} =~ ^-[a-zA-Z]$ ]]; then
      this_arg=${arg#-}
      eval "_opts_s_tigger_${this_arg}=1"
      if [[ -n ${__BASHFUNC_OPTS_VALUE_R[${this_arg}]} ]]; then
        to_store_value_s=${this_arg}
      fi
    elif [[ ${arg} =~ ^--.+ ]]; then
      this_arg=${arg#--}
      eval "_opts_l_tigger_${this_arg}=1"
      if [[ -n ${__BASHFUNC_OPTS_VALUE_R[${this_arg}]} ]]; then
        to_store_value_l=${this_arg}
      fi
    elif [[ ${arg} =~ ^--$ ]]; then
      is_remaining=1
    fi
  done
}
#
# BASHFUNC02: _opts
# **END**
#
