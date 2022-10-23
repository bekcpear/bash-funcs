#
# **BEGIN**
# BASHFUNC00: _do COMMAND {ARGUMENT}
#
#  Author: Ryan Qian <i@bitbili.net>
# License: GPL-2
#
# Print command and arguments to default stdout with
# a different FD number, so it won't affect or be affected by FD 1,
# and run it with all passed arguments
#
# the output can be controled by _BASHFUNC_DO_OFD var after this file sourced
#   e.g.:  eval "exec ${_BASHFUNC_DO_OFD}>/path/to/file"
# or directly assign a valid FD number to _BASHFUNC_DO_OFD before source this file
#
[[ -z ${_BASHFUNC_DO} ]] || return 0
_BASHFUNC_DO=1

if [[ -z ${_BASHFUNC_DO_OFD} ]]; then
  eval "exec {_BASHFUNC_DO_OFD}>$(realpath /proc/$$/fd/1)"
fi

_do() {
  [[ -n ${1} ]] || return 0
  eval "echo -en \"\\x1b[1m\\x1b[32m>>> \\x1b[0m\" >&${_BASHFUNC_DO_OFD}"
  eval "echo \"\${@}\" >&${_BASHFUNC_DO_OFD}"
  "${@}"
}
#
# BASHFUNC00: _do COMMAND {ARGUMENT}
# **END**
#
