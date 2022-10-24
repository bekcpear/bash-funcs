#!/usr/bin/env bash
#

. "$(dirname $(realpath $0))/../_do.sh"
. "$(dirname $(realpath $0))/../_log.sh"
. "$(dirname $(realpath $0))/../_vercmp.sh"

cmp0=("element-v1.11.11-rc.2.tar.gz" "element-v1.11.11-rc.1.tar.gz" "g" 0)
cmp1=("v1.11.11-rc.1" "v1.11.11" "g" 1)
cmp2=("v5.1.0" "v5.2.0-a.1" "l" 0)
cmp3=("5.10.149" "5.15.74" "e" 1)
cmp4=("5.10.149" "5.15.74" "g" 1)
cmp5=("5.10.149" "5.15.74" "l" 0)
cmp6=("106.0.5249.119" "106.0.5249.119" "e" 0)
cmp7=("2.20220106" "2.20220520" "l" 0)
cmp8=("headscale-v0.17.0-alpha4" "headscale-v0.17.0-alpha3" "g" 0)
cmp9=("headscale-v0.17.0" "headscale-v0.17.0-alpha3" "g" 0)
cmp10=("headscale-v0.17.0-alpha.10" "headscale-v0.17.0-alpha.3" "g" 0)
cmp11=("1.2.0" "1.2" "g" 0)
cmp12=("1.2.0" "1.2" "e" 1)

ret=0
for (( i=0; i<13; i++ )); do
  v0="cmp${i}[0]"
  v1="cmp${i}[1]"
  ac="cmp${i}[2]"
  re="cmp${i}[3]"

  _do _vercmp ${!ac} ${!v0} ${!v1}
  res=$?
  
  if [[ ${res} != ${!re} ]]; then
    ret=1
    _log e "error: '${!v0}' and '${!v1}', action: '${!ac}', expect: '${!re}', actual: '${res}'"
  fi
done

exit $ret
