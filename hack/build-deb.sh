#!/bin/bash

# SPDX-FileCopyrightText: Copyright The Lima Authors
# SPDX-License-Identifier: Apache-2.0

set -eu -o pipefail

usage() {
	echo "Usage: $0 VERSION ARCH OUTPUT" >&2
	exit 2
}

[[ $# -eq 3 ]] || usage

version=$1
architecture=$2
output=$3

# Debian versions must start with a digit. Tagged Lima versions already do;
# normalize commit-derived development versions such as "abc1234.m".
package_version=$version
if [[ $package_version != [0-9]* ]]; then
	package_version="0~git.$package_version"
fi

case "$architecture" in
	amd64) qemu_dependency=qemu-system-x86 ;;
	arm64) qemu_dependency=qemu-system-arm ;;
	*) echo "unsupported Debian architecture: $architecture" >&2; exit 1 ;;
esac

if [[ $(uname -s) != Linux ]]; then
	echo "Debian packages can only be built on Linux" >&2
	exit 1
fi

command -v dpkg-deb >/dev/null 2>&1 || {
	echo "dpkg-deb is required to build Debian packages" >&2
	exit 1
}

mkdir -p "$(dirname "$output")"
package_dir=$(mktemp -d)
trap 'rm -rf "$package_dir"' EXIT

mkdir -p "$package_dir/DEBIAN" "$package_dir/usr"
cp -a _output/. "$package_dir/usr/"

cat >"$package_dir/DEBIAN/control" <<EOF
Package: lima
Version: $package_version
Section: utils
Priority: optional
Architecture: $architecture
Maintainer: Lima Authors <lima-maintainers@googlegroups.com>
Depends: $qemu_dependency, qemu-utils, openssh-client, sudo
Description: Linux virtual machines
 Lima launches Linux virtual machines with automatic file sharing and port forwarding.
 It supports containerd, Docker, Podman, Kubernetes, and non-container workloads.
EOF

dpkg-deb --build --root-owner-group "$package_dir" "$output"
