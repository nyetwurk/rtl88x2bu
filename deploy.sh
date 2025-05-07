#!/bin/bash

set -euo pipefail

function main() {
    local VERSION
    VERSION="$(get_version)"
    ensure_no_cli_args "$@"
    ensure_root_permissions
    remove_driver &>/dev/null || true
    put_sources_in_place "$VERSION"
    deploy_driver "$VERSION"
}

function ensure_no_cli_args() {
    if [ $# -ne 0 ]; then
        echo "No command line arguments accepted!" >&2
        exit 1
    fi
}

function ensure_root_permissions() {
    if ! sudo -v; then
        echo "Root permissions required to deploy the driver!" >&2
        exit 1
    fi
}

function get_version() {
    sed -En 's/PACKAGE_VERSION="(.*)"/\1/p' dkms.conf
}

function remove_driver() {
    sudo dkms remove rtl88x2bu/5.8.7.1 --all
}

function put_sources_in_place() {
    local VERSION="$1"
    sudo rsync --delete --exclude=.git -rvhP ./ "/usr/src/rtl88x2bu-${VERSION}"
}

function deploy_driver() {
    local VERSION="$1"
    sudo dkms "add" -m rtl88x2bu -v "${VERSION}"
    find /boot -maxdepth 1 -iname "initrd.img*" |
        cut -d- -f2- |
        while read -r kernel; do
            # xargs -n1 sudo dkms install -m rtl88x2bu -v 5.8.7.1 -k
            for action in build install; do
                sudo dkms "${action}" -m rtl88x2bu -v "${VERSION}" -k "${kernel}"
            done
        done
    sudo modprobe 88x2bu
}

main "$@"
