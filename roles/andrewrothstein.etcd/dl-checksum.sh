#!/usr/bin/env sh
set -e
DIR=~/Downloads
MIRROR=https://github.com/etcd-io/etcd/releases/download

dl()
{
    local ver=$1
    local lshasum=$2
    local os=$3
    local arch=$4
    local archive_type=${5:-tar.gz}
    local platform="${os}-${arch}"
    local file=etcd-${ver}-${platform}.${archive_type}
    local url=$MIRROR/$ver/$file
    printf "    # %s\n" $url
    printf "    %s: sha256:%s\n" $platform $(grep $file $lshasum | awk '{print $1}')
}

dl_ver() {
    local ver=$1
    local rshasum=$MIRROR/$ver/SHA256SUMS
    local lshasum=$DIR/etcd-${ver}-SHA256SUMS

    if [ ! -e $lshasum ]; then
        wget -q -O $lshasum $rshasum
    fi

    printf "  # %s\n" $rshasum
    printf "  %s:\n" $ver
    dl $ver $lshasum darwin amd64 zip
    dl $ver $lshasum linux amd64
    dl $ver $lshasum linux arm64
    dl $ver $lshasum linux ppc64le
    dl $ver $lshasum windows amd64 zip
}

dl_ver ${1:-v3.4.14}
