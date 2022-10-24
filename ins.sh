#!/usr/bin/env bash
#
#  Author: Ryan Qian <i@bitbili.net>
# License: GPL-2
#
# This is used to insert/update unit function into specified bash file
# after an anchor beginning with "###_BASHFUNC or after the first uncommented line"
#

_func_dir=$(dirname $(realpath $0))
. ${_func_dir}/_log.sh
. ${_func_dir}/_do.sh
. ${_func_dir}/_opts.sh

_BASHFUNC_OPTS_USAGE="[-r] <SCRIPT-FILE-PATH> <FUNCTION-NAME>"
_BASHFUNC_OPTS_DESC="insert/update all content from file specified by <FUNCTION-NAME> into <SCRIPT-FILE-PATH>
after an anchor beginning with \"###_BASHFUNC\" or after the first uncommented line"

_opts_add -o r -l remove -i "remove the specified function"
_opts_add -o h -l help -i "show this help"

_opts_handle "${@}"
set -- "${_opts_remaining[@]}"

if [[ -n ${_opts_trigger_h} ]]; then
  _bashfunc_help
  exit
fi
if [[ -n ${_opts_trigger_r} ]]; then
  removeonly=1
fi

_dest="${1}"
_src="${2}"

if [[ -z ${_dest} ]] || [[ -z ${_src} ]]; then
  _bashfunc_help
  exit 1
fi

if [[ ! ${_src} =~ ^(/|~) ]]; then
  _real_src=$(ls -1 ${_func_dir}/*${_src}* 2>/dev/null | head -1)
  if [[ -z ${_real_src} ]]; then
    _real_src=$(ls -1 ${_func_dir}/*${_dest}* 2>/dev/null | head -1)
    if [[ -z ${_real_src} ]]; then
      _log ee _help "cannot find the function file '${_src}' to insert."
    else
      _dest=${_src}
    fi
  fi
else
  _real_src=${_src}
fi

_dest=$(realpath ${_dest})

[[ -f ${_dest} ]] || \
    _log ee _help "'${_dest}' is not a regular file as the destination."

# remove old
_func_match="$(grep -E '^# BASHFUNC[[:digit:]]' ${_real_src} | head -1 | cut -d' ' -f1-3)"
eval "_func_match_nums=(\$(sed -nE '/^${_func_match}/=' ${_dest}))"
if [[ ${#_func_match_nums[@]} -gt 0 ]]; then
  if [[ ${#_func_match_nums[@]} == 2 ]]; then
    _begin=${_func_match_nums[0]}
    if [[ $(eval "sed -nE '$((${_begin}-1))p' '${_dest}'") =~ ^#[[:space:]]*\*\*BEGIN ]]; then
      _begin=$(( ${_begin} - 1 ))
      if [[ $(eval "sed -nE '$((${_begin}-1))p' '${_dest}'") =~ ^#[[:space:]]*$ ]]; then
        _begin=$(( ${_begin} - 1 ))
      fi
    fi
    _end=${_func_match_nums[1]}
    if [[ $(eval "sed -nE '$((${_end}+1))p' '${_dest}'") =~ ^#[[:space:]]*\*\*END ]]; then
      _end=$(( ${_end} + 1 ))
      if [[ $(eval "sed -nE '$((${_end}+1))p' '${_dest}'") =~ ^#[[:space:]]*$ ]]; then
        _end=$(( ${_end} + 1 ))
      fi
    fi
    _do sed -i "${_begin},${_end}d" "${_dest}"
  else
    _log ee "too many matches(${#_func_match_nums[@]}) at line ${_func_match_nums[@]} for '${_real_src}', please handle manually."
  fi
fi

[[ -z ${removeonly} ]] || exit 0

# get the insert line num
_ins_line=$(sed -nE '/^[[:space:]]*###_BASHFUNC/=' "${_dest}" | head -1)
if [[ -z ${_ins_line} ]]; then
  _ins_line=$(sed -nE '/^[[:space:]]*#/!=' "${_dest}" | head -1)
  if [[ -z ${_ins_line} ]]; then
    _ins_line=0
  fi
fi

# do insert
_do sed -Ei "${_ins_line}r${_real_src}" "${_dest}"
