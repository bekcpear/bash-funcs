#
# **BEGIN**
# BASHFUNC01: _log (d|i|w|e)|(ee [FUNCNAME]) MSG-STRING {MSG-STRING}
#
#  Author: Ryan Qian <i@bitbili.net>
# License: GPL-2
#
# Log to specified destination, the destination is controled by
#
# variable:
#   _BASHFUNC_LOG_OUT_FD <FD-NUM>
# default:
#   1
#
# variable:
#   _BASHFUNC_LOG_ERR_FD <FD-NUM>
# default:
#   2
#
# with different levels
#
#   e: print to error level
#   w: print to warning and above levels
#   i: print to info and above levels
#   d: print to debug and above levels
#
#   ee: print to error level and
#       exit with ${_BASHFUNC_LAST_EXIT}
#                 or $?
#                 or 1
#       this mode can specify a function to call before exit
#       just pass the function name after ee
#
# the output level is controled by
#
# variable:
#   _BASHFUNC_LOG_LEVEL error|warning|info|debug
# default:
#   warning
#
# warning and error logs will print to _BASHFUNC_LOG_ERR_FD
#    info and debug logs will print to _BASHFUNC_LOG_OUT_FD
#
# the output string can also be prefixed with a datetime,
# which controled by
#
# variable:
#   _BASHFUNC_LOG_DATE on|off
# default:
#   on
#
# variable:
#   _BASHFUNC_LOG_DATE_FORMAT <DATE-FORMAT-PATTERN>
# default:
#   +%Y-%m-%d %H:%M:%S
#
[[ -z ${_BASHFUNC_LOG} ]] || return 0
_BASHFUNC_LOG=1

: ${_BASHFUNC_LOG_LEVEL:=warning}
: ${_BASHFUNC_LOG_OUT_FD:=1}
: ${_BASHFUNC_LOG_ERR_FD:=2}
: ${_BASHFUNC_LOG_DATE:=on}
: ${_BASHFUNC_LOG_DATE_FORMAT:="+%Y-%m-%d %H:%M:%S"}

declare -A _BASHFUNC_LOG_LEVEL_INTERNAL=(
  [debug]=3
  [info]=2
  [warning]=1
  [error]=0
)

_log() {
  : ${_BASHFUNC_LAST_EXIT:=$?} # this should always at the first line of this function
  [[ -n ${2} ]] || return 0

  local lv=${_BASHFUNC_LOG_LEVEL_INTERNAL[${_BASHFUNC_LOG_LEVEL}]}
  local out= format= fatal= endfunc=
  case ${1} in
    d)
      if [[ ${lv} -lt 3 ]]; then
        return 0
      fi
      out=${_BASHFUNC_LOG_OUT_FD}
      format='\x1b[1m'
      ;;
    i)
      if [[ ${lv} -lt 2 ]]; then
        return 0
      fi
      out=${_BASHFUNC_LOG_OUT_FD}
      ;;
    w)
      if [[ ${lv} -lt 1 ]]; then
        return 0
      fi
      out=${_BASHFUNC_LOG_ERR_FD}
      format='\x1b[1m\x1b[33m'
      ;;
    e)
      out=${_BASHFUNC_LOG_ERR_FD}
      format='\x1b[1m\x1b[31m'
      ;;
    ee)
      out=${_BASHFUNC_LOG_ERR_FD}
      format='\x1b[1m\x1b[31m'
      fatal=${1}
      if declare -F "${2}" &>/dev/null; then
        endfunc=${2}
        shift
      fi
      ;;
    *)
      echo "internal function error: _log, unexpected argument '$1'" >&2
      return 1
      ;;
  esac
  shift

  if [[ ${_BASHFUNC_LOG_DATE} == "on" ]]; then
    local datetime="[$(date '+%Y-%m-%d %H:%M:%S')] "
  fi

  eval ">&${out} echo -ne '${format}${datetime}'"
  eval ">&${out} echo -n  \"\${@}\""
  eval ">&${out} echo -e  '\\x1b[0m'"

  if [[ ${fatal} == "ee" ]]; then
    if [[ ${_BASHFUNC_LAST_EXIT} == 0 ]]; then
      _BASHFUNC_LAST_EXIT=1
    fi
    ${endfunc}
    exit ${_BASHFUNC_LAST_EXIT}
  fi
}
#
# BASHFUNC01: _log (d|i|w|e)|(ee [FUNCNAME]) MSG-STRING {MSG-STRING}
# **END**
#
