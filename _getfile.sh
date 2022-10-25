#
# **BEGIN**
# BASHFUNC04: _getfile
#
#  Author: Ryan Qian <i@bitbili.net>
# License: GPL-2
#
# This is used to get contents from remote, it will first check if
# the file is already exists locally by the provided local file path.
# And also check the file for corruption if a hash string or signature file provided.
#
# If file not exists or is already corrupted, remove it and download from remote again.
#
# There are two functions to control this progress.
#
# function:
#   _getfile_queue { -v " DETAILS " } -l LOCAL-PATH -r REMOTE-URL
# description:
#   add download task to the queue
# options:
#   -v "DETAILS"
#     add the verify method, can be provided multiple times;
#      the all added method will be processed, the entire verification fails once a method fails;
#      if verification fails, the downloaded contents will be removed, and try again
#     DETAILS format: METHOD MORE-DETAILS
#     METHOD is one of    sig:  use binded signature to verify
#                               MORE-DETAILS: FINGERPRINT [KEY-URL]
#                                if KEY-URL not provided and key does not exists,
#                                it will try to import key from the default key server
#                                FINGERPRINT: fp:<hex-string>
#                                    KEY-URL: key:<url>
#                        dsig:  use detached signature file to verify
#                               MORE-DETAILS: [L-PATH] URL FINGERPRINT [KEY-URL]
#                                if L-PATH provided and exists, it will use this file to check
#                                                               without downloading from remote;
#                                                if not exists, the downloaded signature will be
#                                                               stored to this L-PATH and won't
#                                                               be removed when verified.
#                                     L-PATH: path:/path/to/file
#                                        URL: url:<url>
#                                FINGERPRINT: fp:<hex-string>
#                                    KEY-URL: key:<url>
#                          b2:
#                         md5:
#                        sha1:
#                      sha256:
#                      sha384:
#                      sha512:  use hash string or string within the seperated file to verify
#                               MORE-DETAILS: HASH|URL
#                                       HASH: hash:<string>
#                                        URL: url:<url>
#
# function:
#   _getfile
# description:
#   do get contents from remote
#
# There are also a set of variables to control some features.
#
# variable:
#   _BASHFUNC_GETFILE_FORCE_VERIFICATION
# default:
#   <UNSET>
# description:
#   force the verification of at least once.
#   Note: a false verification (not skipped one) always fails the whole verification
#
# variable:
#   _BASHFUNC_GETFILE_DOWNLOAD_CMD
# default:
#   curl --retry 3 -Lfo \"\${_file}\" \"\${_url}\"
# description:
#   the default download command,
#   \"\${_file}\" and \"\${_url}\" should be used as the same format
#
# example:
#   . /path/to/_getfile.sh
#   _getfile_queue -v "dsig fp:${fp} key:${key_url} url:${asc_url} path:${local_key_path}" \
#                  -l ${tarball_path} -r ${tarball_url}
#   _getfile_queue -v "sha256 hash:affc8559df1d9e90b787c77df6ad429bc345a6c508480ea48d975342024113c7" \
#                  -l ${file_path} -r ${file_url}
#   _getfile_queue -v "sha512 url:https://example.com/filename.sha256.txt" \
#                  -l ${file1_path} -r ${file1_url}
#   _getfile
#
[[ -z ${_BASHFUNC_GETFILE} ]] || return 0
_BASHFUNC_GETFILE=1

declare -i __BASHFUNC_GETFILE_FILE_INDEX=0
declare -a __BASHFUNC_GETFILE_FILE_LOCAL \
           __BASHFUNC_GETFILE_FILE_REMOTE \
           __BASHFUNC_GETFILE_FILE_HAS_VMETHOD \
           __BASHFUNC_GETFILE_FILE_SIG_TYPE \
           __BASHFUNC_GETFILE_FILE_SIG_LOCAL \
           __BASHFUNC_GETFILE_FILE_SIG_REMOTE \
           __BASHFUNC_GETFILE_FILE_SIG_KEY_FP \
           __BASHFUNC_GETFILE_FILE_SIG_KEY_REMOTE \
           __BASHFUNC_GETFILE_FILE_HASH_B2 \
           __BASHFUNC_GETFILE_FILE_HASH_B2_TYPE \
           __BASHFUNC_GETFILE_FILE_HASH_MD5 \
           __BASHFUNC_GETFILE_FILE_HASH_MD5_TYPE \
           __BASHFUNC_GETFILE_FILE_HASH_SHA1 \
           __BASHFUNC_GETFILE_FILE_HASH_SHA1_TYPE \
           __BASHFUNC_GETFILE_FILE_HASH_SHA256 \
           __BASHFUNC_GETFILE_FILE_HASH_SHA256_TYPE \
           __BASHFUNC_GETFILE_FILE_HASH_SHA384 \
           __BASHFUNC_GETFILE_FILE_HASH_SHA384_TYPE \
           __BASHFUNC_GETFILE_FILE_HASH_SHA512 \
           __BASHFUNC_GETFILE_FILE_HASH_SHA512_TYPE

__bashfunc_getfile_queue_missing_arg() {
  if [[ -z ${1} ]]; then
    echo "internal function error: _getfile_queue, missing necessary argument '${2}' for '${3}' verify method." >&2
    return 1
  fi
}
_getfile_queue() {
  local -a v
  local l r index next_index
  while [[ -n "${1}" ]]; do
    if [[ ${1} == '-v' ]]; then
      shift
      v+=("${1}")
    elif [[ ${1} == '-l' ]]; then
      shift
      l="${1}"
    elif [[ ${1} == '-r' ]]; then
      shift
      r="${1}"
    else
      echo "internal function error: _getfile_queue, unexpected argument '${1}'" >&2
      return 1
    fi
    shift
  done

  if [[ -z ${l} ]]; then
    echo "internal function error: _getfile_queue, missing necessary argument 'LOCAL-PATH'." >&2
    return 1
  fi
  if [[ -z ${r} ]]; then
    echo "internal function error: _getfile_queue, missing necessary argument 'REMOTE-URL'." >&2
    return 1
  fi

  for (( _i = 0; _i < ${__BASHFUNC_GETFILE_FILE_INDEX}; _i++ )) do
    if [[ $(realpath -m "${__BASHFUNC_GETFILE_FILE_LOCAL[$_i]}") == $(realpath -m "${l}") ]]; then
      echo "internal function warning: _getfile_queue, the local path '${l}' already queued." >&2
      echo "                                           update existing attributes ..." >&2
      # if an attribute exists,
      # but you don't provid a new one to override it,
      # the old one will not be removed
      index=${_i}
      next_index=${__BASHFUNC_GETFILE_FILE_INDEX}
    fi
  done
  : ${index:=${__BASHFUNC_GETFILE_FILE_INDEX}}
  __BASHFUNC_GETFILE_FILE_LOCAL[${index}]="${l}"
  __BASHFUNC_GETFILE_FILE_REMOTE[${index}]="${r}"

  local _method _detail
  local -a _details
  for _v in "${v[@]}"; do
    <<<"${_v}" read _method _detail
    _details=(${_detail})
    local -A _details_arg
    for _d in "${_details[@]}"; do
      eval "_details_arg[${_d%%:*}]=\"${_d#*:}\""
    done
    case ${_method} in
      sig)
        __BASHFUNC_GETFILE_FILE_SIG_TYPE[${index}]="binded"
        __BASHFUNC_GETFILE_FILE_SIG_KEY_FP[${index}]="${_details_arg[fp]}"
        __BASHFUNC_GETFILE_FILE_SIG_KEY_REMOTE[${index}]="${_details_arg[key]}"
        __bashfunc_getfile_queue_missing_arg ${__BASHFUNC_GETFILE_FILE_SIG_KEY_FP[${index}]} fp sig || return $?
        __BASHFUNC_GETFILE_FILE_HAS_VMETHOD[${index}]=1
        ;;
      dsig)
        __BASHFUNC_GETFILE_FILE_SIG_TYPE[${index}]="detached"
        __BASHFUNC_GETFILE_FILE_SIG_LOCAL[${index}]="${_details_arg[path]}"
        __BASHFUNC_GETFILE_FILE_SIG_REMOTE[${index}]="${_details_arg[url]}"
        __BASHFUNC_GETFILE_FILE_SIG_KEY_FP[${index}]="${_details_arg[fp]}"
        __BASHFUNC_GETFILE_FILE_SIG_KEY_REMOTE[${index}]="${_details_arg[key]}"
        if [[ -z ${__BASHFUNC_GETFILE_FILE_SIG_LOCAL[${index}]} ]] && \
           [[ -z ${__BASHFUNC_GETFILE_FILE_SIG_REMOTE[${index}]} ]]; then
          __bashfunc_getfile_queue_missing_arg "" "path/url" dsig || return $?
        fi
        __bashfunc_getfile_queue_missing_arg ${__BASHFUNC_GETFILE_FILE_SIG_KEY_FP[${index}]} fp dsig || return $?
        __BASHFUNC_GETFILE_FILE_HAS_VMETHOD[${index}]=1
        ;;
      b2)
        __BASHFUNC_GETFILE_FILE_HASH_B2[${index}]=${_details_arg[hash]:-${_details_arg[url]}}
        __BASHFUNC_GETFILE_FILE_HASH_B2_TYPE[${index}]=${_details_arg[hash]:+hash}
        __bashfunc_getfile_queue_missing_arg ${__BASHFUNC_GETFILE_FILE_HASH_B2[${index}]} "hash/url" b2 || return $?
        __BASHFUNC_GETFILE_FILE_HAS_VMETHOD[${index}]=1
        ;;
      md5)
        __BASHFUNC_GETFILE_FILE_HASH_MD5[${index}]=${_details_arg[hash]:-${_details_arg[url]}}
        __BASHFUNC_GETFILE_FILE_HASH_MD5_TYPE[${index}]=${_details_arg[hash]:+hash}
        __bashfunc_getfile_queue_missing_arg ${__BASHFUNC_GETFILE_FILE_HASH_MD5[${index}]} "hash/url" md5 || return $?
        __BASHFUNC_GETFILE_FILE_HAS_VMETHOD[${index}]=1
        ;;
      sha1)
        __BASHFUNC_GETFILE_FILE_HASH_SHA1[${index}]=${_details_arg[hash]:-${_details_arg[url]}}
        __BASHFUNC_GETFILE_FILE_HASH_SHA1_TYPE[${index}]=${_details_arg[hash]:+hash}
        __bashfunc_getfile_queue_missing_arg ${__BASHFUNC_GETFILE_FILE_HASH_SHA1[${index}]} "hash/url" sha1 || return $?
        __BASHFUNC_GETFILE_FILE_HAS_VMETHOD[${index}]=1
        ;;
      sha256)
        __BASHFUNC_GETFILE_FILE_HASH_SHA256[${index}]=${_details_arg[hash]:-${_details_arg[url]}}
        __BASHFUNC_GETFILE_FILE_HASH_SHA256_TYPE[${index}]=${_details_arg[hash]:+hash}
        __bashfunc_getfile_queue_missing_arg ${__BASHFUNC_GETFILE_FILE_HASH_SHA256[${index}]} "hash/url" sha256 || return $?
        __BASHFUNC_GETFILE_FILE_HAS_VMETHOD[${index}]=1
        ;;
      sha384)
        __BASHFUNC_GETFILE_FILE_HASH_SHA384[${index}]=${_details_arg[hash]:-${_details_arg[url]}}
        __BASHFUNC_GETFILE_FILE_HASH_SHA384_TYPE[${index}]=${_details_arg[hash]:+hash}
        __bashfunc_getfile_queue_missing_arg ${__BASHFUNC_GETFILE_FILE_HASH_SHA384[${index}]} "hash/url" sha384 || return $?
        __BASHFUNC_GETFILE_FILE_HAS_VMETHOD[${index}]=1
        ;;
      sha512)
        __BASHFUNC_GETFILE_FILE_HASH_SHA512[${index}]=${_details_arg[hash]:-${_details_arg[url]}}
        __BASHFUNC_GETFILE_FILE_HASH_SHA512_TYPE[${index}]=${_details_arg[hash]:+hash}
        __bashfunc_getfile_queue_missing_arg ${__BASHFUNC_GETFILE_FILE_HASH_SHA512[${index}]} "hash/url" sha512 || return $?
        __BASHFUNC_GETFILE_FILE_HAS_VMETHOD[${index}]=1
        ;;
      *)
        echo "internal function error: _getfile_queue, unexpected verify method '${_method}'" >&2
        return 1
        ;;
    esac
  done

  __BASHFUNC_GETFILE_FILE_INDEX=${next_index:-$(( ${__BASHFUNC_GETFILE_FILE_INDEX} + 1 ))}
}

__bashfunc_getfile_do() {
  if [[ -n ${_BASHFUNC_DO} ]]; then
    _do -p '***_getfile***' "${@}"
  else
    echo -n "***_getfile*** >>> " >&2
    echo "${@}" >&2
    "${@}"
  fi
}
__bashfunc_getfile_log() {
  local lv="${1}"
  shift
  set -- '***_getfile***' "${@}"
  if [[ -n ${_BASHFUNC_LOG} ]]; then
    _log ${lv} "${@}"
  else
    echo "${@}" >&2
  fi
}
: ${_BASHFUNC_GETFILE_DOWNLOAD_CMD:="curl --retry 3 -Lfo \"\${_file}\" \"\${_url}\""}
__bashfunc_getfile_curl() {
  local dir=$(dirname "${1}") _file="${1}" _url="${2}"
  if [[ ! -d "${dir}" ]]; then
    if [[ -e "${dir}" ]]; then
      __bashfunc_getfile_log e "'${dir}' exists but is not a directory"
      return 1
    fi
    __bashfunc_getfile_do mkdir -p "${dir}" || return $?
  fi
  eval "__bashfunc_getfile_do ${_BASHFUNC_GETFILE_DOWNLOAD_CMD}"
}
__bashfunc_getfile_key_import() {
  if [[ -n "${1}" ]]; then
    __bashfunc_getfile_log i "download key from '${1}' ..."
    local tmpfile=$(mktemp -u)
    __bashfunc_getfile_curl "${tmpfile}" "${1}"
    __bashfunc_getfile_do gpg --import "${tmpfile}"
    __bashfunc_getfile_do rm -f "${tmpfile}"
  else
    __bashfunc_getfile_log w "key url does not provide, try importing from the default key server ..."
    __bashfunc_getfile_do gpg --receive-key "${2}"
  fi
}
__bashfunc_getfile_key_exists() {
  if ! gpg --list-key "${1}" &>/dev/null; then
    return 1
  fi
}
_getfile() {
  (
    local ret=0 _ret=0
    local -a trashes
    clear_trashes() {
      local _i _count=${#trashes[@]}
      if [[ ${_count} -gt 0 ]]; then
        __bashfunc_getfile_log i "remove trashes ..."
      fi
      for (( _i = 0; _i < ${_count}; _i++ )); do
        __bashfunc_getfile_do rm -f "${trashes[$_i]}"
        eval "unset trashes[$_i]"
      done
      exit ${ret}
    }
    trap 'clear_trashes' EXIT

    for (( i = 0; i < ${__BASHFUNC_GETFILE_FILE_INDEX}; i++ )); do
      local fp= key= sig_path= sig_url= path= downloaded= completed= tmpfile=
      local -a h= h_type= h_cmd=

      __getfile() {
        path=${__BASHFUNC_GETFILE_FILE_LOCAL[$i]}
        ___verify_fail_handler() {
          __bashfunc_getfile_log e "verify '${path}' failed with method '${1}', removing it ..."
          __bashfunc_getfile_do rm -f "${path}"
        }

        # check if force verification set
        if [[ -z ${__BASHFUNC_GETFILE_FILE_HAS_VMETHOD[${i}]} ]] && \
           [[ -n ${_BASHFUNC_GETFILE_FORCE_VERIFICATION} ]]; then
          __bashfunc_getfile_log w "force verification is set, but there is no verify method for file '${path}', skipping ..."
          completed=1
          return 1
        fi

        # download if local file does not exists
        if [[ ! -e ${path} ]]; then
          downloaded=1
          __bashfunc_getfile_curl "${path}" "${__BASHFUNC_GETFILE_FILE_REMOTE[$i]}" || return $?
        fi

        # do verification
        # verify signature
        if [[ -n ${__BASHFUNC_GETFILE_FILE_SIG_TYPE[$i]} ]]; then
          fp="0x${__BASHFUNC_GETFILE_FILE_SIG_KEY_FP[$i]#0x}"
          key="${__BASHFUNC_GETFILE_FILE_SIG_KEY_REMOTE[$i]}"
          __bashfunc_getfile_log i "verifying '${path}' by signature with key '${fp}' ..."
          if ! __bashfunc_getfile_key_exists "${fp}"; then
            __bashfunc_getfile_log w "key '${fp}' does not exist"
            __bashfunc_getfile_key_import "${key}" "${fp}"
          fi
          if ! __bashfunc_getfile_key_exists "${fp}"; then
            __bashfunc_getfile_log e "key '${fp}' is still does not exist, skip verifying signature ..."
          else
            case ${__BASHFUNC_GETFILE_FILE_SIG_TYPE[$i]} in
              binded)
                __bashfunc_getfile_log i "binded signature"
                tmpfile=$(mktemp -u)
                if __bashfunc_getfile_do gpg --output "${tmpfile}" --decrypt "${path}"; then
                  __bashfunc_getfile_do mv "${tmpfile}" "${path}"
                else
                  ___verify_fail_handler "binded signature"
                  return 1
                fi
                ;;
              detached)
                __bashfunc_getfile_log i "detached signature"
                sig_path="${__BASHFUNC_GETFILE_FILE_SIG_LOCAL[$i]}"
                sig_url="${__BASHFUNC_GETFILE_FILE_SIG_REMOTE[$i]}"
                if [[ -e "${sig_path}" ]]; then
                  __bashfunc_getfile_log i "use local signature file '${sig_path}' to verify ..."
                else
                  if [[ -z ${sig_path} ]]; then
                    sig_path="$(mktemp -u)"
                    trashes+=("${sig_path}")
                  fi
                  __bashfunc_getfile_log i "downloading signature file from '${sig_url}' ..."
                  __bashfunc_getfile_curl "${sig_path}" "${sig_url}"
                fi
                if ! __bashfunc_getfile_do gpg --verify "${sig_path}" "${path}"; then
                  ___verify_fail_handler "detached signature"
                  return 1
                fi
                ;;
            esac
          fi
        fi

        # verify hash
        ___check_hash() {
          __bashfunc_getfile_log i "verifying '${path}' by '${3}' ..."
          local bname=$(basename "${path}") _h _match _file
          if [[ -z ${1} ]]; then
            _file=$(mktemp -u)
            trashes+=("${_file}")
            __bashfunc_getfile_log i "getting hash value from '${2}' ..."
            __bashfunc_getfile_curl "${_file}" "${2}"
            h=($(grep -E "${bname}[[:space:]]*$" | cur -d' ' -f1))
          else
            h=(${2})
          fi
          _h=$("${3}" "${path}" | cut -d' ' -f1)
          for __h in "${h[@]}"; do
            __bashfunc_getfile_log i "checking hash ..."
            __bashfunc_getfile_log i "  expect: ${__h}"
            __bashfunc_getfile_log i "  actual: ${_h}"
            if [[ "${__h}" == "${_h}" ]]; then
              _match=1
            fi
          done
          if [[ -z ${_match} ]]; then
            ___verify_fail_handler "${3}"
            return 1
          fi
        }
             h+=(${__BASHFUNC_GETFILE_FILE_HASH_B2[$i]})
        h_type+=(${__BASHFUNC_GETFILE_FILE_HASH_B2_TYPE[$i]})
         h_cmd+=("b2sum")
             h+=(${__BASHFUNC_GETFILE_FILE_HASH_MD5[$i]})
        h_type+=(${__BASHFUNC_GETFILE_FILE_HASH_MD5_TYPE[$i]})
         h_cmd+=("md5sum")
             h+=(${__BASHFUNC_GETFILE_FILE_HASH_SHA1[$i]})
        h_type+=(${__BASHFUNC_GETFILE_FILE_HASH_SHA1_TYPE[$i]})
         h_cmd+=("sha1sum")
             h+=(${__BASHFUNC_GETFILE_FILE_HASH_SHA256[$i]})
        h_type+=(${__BASHFUNC_GETFILE_FILE_HASH_SHA256_TYPE[$i]})
         h_cmd+=("sha256sum")
             h+=(${__BASHFUNC_GETFILE_FILE_HASH_SHA384[$i]})
        h_type+=(${__BASHFUNC_GETFILE_FILE_HASH_SHA384_TYPE[$i]})
         h_cmd+=("sha384sum")
             h+=(${__BASHFUNC_GETFILE_FILE_HASH_SHA512[$i]})
        h_type+=(${__BASHFUNC_GETFILE_FILE_HASH_SHA512_TYPE[$i]})
         h_cmd+=("sha512sum")
        for (( j = 0; j < ${#h[@]}; j++ )); do
          if [[ -n ${h[$j]} ]]; then
            ___check_hash "${h_type[$j]}" "${h[$j]}" "${h_cmd[$j]}" || return $?
          fi
        done

        completed=1
      }

      # retry if not yet download
      while [[ -z ${downloaded} ]] && [[ -z ${completed} ]]; do
        __getfile || _ret=$?
        # save the first error exit code during the whole for loop
        if [[ ${ret} == 0 ]]; then
          ret=${_ret}
        fi
      done

    done
  )
}
#
# BASHFUNC04: _getfile
# **END**
#
