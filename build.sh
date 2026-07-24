#!/bin/bash
#
# Assembles ephemeral build trees under /tmp from the single src/ +
# packaging/ source layout and produces .deb and/or .rpm packages in
# ./dist/.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SRC_DIR="$SCRIPT_DIR/src"
PACKAGING_DIR="$SCRIPT_DIR/packaging"
DIST_DIR="$SCRIPT_DIR/dist"
PKG_NAME=scheduled-reboot

BUILD_ROOT=$(mktemp -d /tmp/scheduled-reboot-build.XXXXXX)
cleanup() { rm -rf -- "$BUILD_ROOT"; }
trap cleanup EXIT

usage() {
    cat <<'EOF'
Usage: build.sh [--all|--deb|--rpm]

  --all   Build both a .deb and an .rpm package (default if no flag given)
  --deb   Build only the .deb package
  --rpm   Build only the .rpm package

Output packages are written to ./dist/.
EOF
}

do_deb=0
do_rpm=0

if [[ $# -eq 0 ]]; then
    do_deb=1
    do_rpm=1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            do_deb=1
            do_rpm=1
            ;;
        --deb)
            do_deb=1
            ;;
        --rpm)
            do_rpm=1
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 64
            ;;
    esac
    shift
done

log() { printf '%s\n' "$*" >&2; }

die() {
    log "build.sh: $*"
    exit 1
}

# Every place a version string is recorded must agree, or the package we
# build will silently disagree with `--version` output or the man page.
check_version_consistency() {
    local control_version spec_version man_version
    local script script_version mismatch=0

    control_version=$(awk -F': *' '/^Version:/{print $2; exit}' "$PACKAGING_DIR/deb/control")
    spec_version=$(awk -F': *' '/^Version:/{print $2; exit}' "$PACKAGING_DIR/rpm/scheduled-reboot.spec")
    man_version=$(grep -m1 '^\.TH' "$SRC_DIR/usr/local/share/man/man8/scheduled-reboot.8" |
        sed -E 's/.*scheduled-reboot ([0-9]+\.[0-9]+).*/\1/')

    log "Version in packaging/deb/control:              $control_version"
    log "Version in packaging/rpm/scheduled-reboot.spec: $spec_version"
    log "Version in man page .TH line:                   $man_version"

    for script in scheduled-reboot post-reboot; do
        script_version=$(grep -m1 -E '^(readonly[[:space:]]+)?VERSION=' "$SRC_DIR/usr/local/bin/$script" | cut -d= -f2 | tr -d "'\"")
        log "Version in usr/local/bin/$script:                  $script_version"
        [[ $script_version == "$control_version" ]] || mismatch=1
    done

    [[ $spec_version == "$control_version" ]] || mismatch=1
    [[ $man_version == "$control_version" ]] || mismatch=1

    ((mismatch == 0)) || die "version strings disagree across packaging files; align them before building (see list above)"
}

check_deb_build_deps() {
    local missing=()
    command -v dpkg-deb >/dev/null 2>&1 || missing+=(dpkg-dev)
    command -v fakeroot >/dev/null 2>&1 || missing+=(fakeroot)
    if ((${#missing[@]})); then
        die "missing build dependencies for .deb: ${missing[*]} (install with: sudo apt-get install ${missing[*]})"
    fi
}

check_rpm_build_deps() {
    local missing=()
    command -v rpmbuild >/dev/null 2>&1 || missing+=(rpm-build)
    if ((${#missing[@]})); then
        die "missing build dependencies for .rpm: ${missing[*]} (install with: sudo dnf install ${missing[*]}  -- or: sudo yum install ${missing[*]})"
    fi
}

build_deb() {
    local version=$1
    local pkg_root="$BUILD_ROOT/deb/$PKG_NAME-$version"

    log "Assembling .deb build tree in $pkg_root"
    mkdir -p "$pkg_root"
    cp -a "$SRC_DIR/." "$pkg_root/"

    mkdir -p "$pkg_root/DEBIAN"
    cp "$PACKAGING_DIR/deb/control" "$PACKAGING_DIR/deb/conffiles" "$pkg_root/DEBIAN/"
    cp "$PACKAGING_DIR/common/preinstall.sh" "$pkg_root/DEBIAN/preinst"
    cp "$PACKAGING_DIR/common/postinstall.sh" "$pkg_root/DEBIAN/postinst"
    cp "$PACKAGING_DIR/common/preremove.sh" "$pkg_root/DEBIAN/prerm"

    # Enforce root-owned, non-group/other-writable modes regardless of the
    # ownership/permissions the source tree happens to have on disk.
    find "$pkg_root" -mindepth 1 -type d -exec chmod 0755 {} +
    find "$pkg_root" -mindepth 1 -type f -exec chmod 0644 {} +
    chmod 0755 \
        "$pkg_root/DEBIAN/preinst" "$pkg_root/DEBIAN/postinst" "$pkg_root/DEBIAN/prerm" \
        "$pkg_root/usr/local/bin/scheduled-reboot" "$pkg_root/usr/local/bin/post-reboot"

    mkdir -p "$DIST_DIR"
    dpkg-deb --build --root-owner-group "$pkg_root" "$DIST_DIR/$PKG_NAME-$version.deb"
    log "Built $DIST_DIR/$PKG_NAME-$version.deb"
}

build_rpm() {
    local version=$1
    local topdir="$BUILD_ROOT/rpm"
    local src_root="$BUILD_ROOT/rpm-src/$PKG_NAME-$version"
    local spec_out="$topdir/SPECS/scheduled-reboot.spec"

    log "Assembling .rpm build tree in $topdir"
    mkdir -p "$topdir"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    mkdir -p "$src_root"
    cp -a "$SRC_DIR/." "$src_root/"
    tar -C "$BUILD_ROOT/rpm-src" -czf "$topdir/SOURCES/$PKG_NAME-$version.tar.gz" "$PKG_NAME-$version"

    # Inline the shared provisioning scripts into the spec's scriptlet
    # sections so their logic stays identical to the .deb maintainer scripts.
    awk -v preinstall="$PACKAGING_DIR/common/preinstall.sh" \
        -v postinstall="$PACKAGING_DIR/common/postinstall.sh" \
        -v preremove="$PACKAGING_DIR/common/preremove.sh" '
        /^@@PREINSTALL@@$/  { while ((getline line < preinstall)  > 0) print line; next }
        /^@@POSTINSTALL@@$/ { while ((getline line < postinstall) > 0) print line; next }
        /^@@PREREMOVE@@$/   { while ((getline line < preremove)   > 0) print line; next }
        { print }
    ' "$PACKAGING_DIR/rpm/scheduled-reboot.spec" >"$spec_out"

    rpmbuild --define "_topdir $topdir" -bb "$spec_out"

    mkdir -p "$DIST_DIR"
    find "$topdir/RPMS" -name '*.rpm' -exec cp -v {} "$DIST_DIR/" \;
}

check_version_consistency

version=$(awk -F': *' '/^Version:/{print $2; exit}' "$PACKAGING_DIR/deb/control")

if ((do_deb)); then
    check_deb_build_deps
    build_deb "$version"
fi

if ((do_rpm)); then
    check_rpm_build_deps
    build_rpm "$version"
fi
