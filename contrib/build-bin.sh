#!/bin/sh
set -e

SCRIPT_NAME="$(basename "$0")"

fatal() { echo "FATAL [$SCRIPT_NAME]: $*" 1>&2; exit 1; }
info() { echo "INFO [$SCRIPT_NAME]: $*"; }

usage() {
cat<<EOF
Syntax: $SCRIPT_NAME /path/to/outdir
Helper script to compile Wireleap components

EOF
exit 1
}

[ -n "$1" ] || usage

command -v go >/dev/null || fatal "go not installed"
command -v make >/dev/null || fatal "make not installed"

OUTDIR="$(realpath "$1")"
[ -d "$OUTDIR" ] || mkdir -p "$OUTDIR"

SRCDIR="$(dirname "$(dirname "$(realpath "$0")")")"
GITVERSION="$($SRCDIR/contrib/gitversion.sh)"

GOOS=${GOOS:-$(go env GOOS)}

if [ "$GOOS" = 'linux' ]; then
    info "building wireleap_intercept (needed for wireleap on linux)"
    make -C "$SRCDIR/wireleap_intercept"
    cp "$SRCDIR/wireleap_intercept/wireleap_intercept.so" "$SRCDIR/sub/initcmd/embedded"
    make -C "$SRCDIR/wireleap_intercept" clean

    info "building wireleap_tun"
    cd "$SRCDIR/wireleap_tun"
    go get -v -d ./...
    CGO_ENABLED=0 go build
    cd -
    mv "$SRCDIR/wireleap_tun/wireleap_tun" "$SRCDIR/sub/initcmd/embedded"
fi

cp "$SRCDIR/LICENSE" "$SRCDIR/sub/initcmd/embedded/"

info "building ..."
CGO_ENABLED=0 go build -tags "$BUILD_TAGS" -o "$OUTDIR/wireleap" -ldflags "
    -X github.com/wireleap/client/version.GITREV=$GITVERSION \
"

[ -z "$BUILD_USER" ] || chown -R "$BUILD_USER" "$OUTDIR"
[ -z "$BUILD_GROUP" ] || chgrp -R "$BUILD_GROUP" "$OUTDIR"

# defined in contrib/docker/build-bin.sh, change here if changed there
DEPSDIR=/go/deps
if [ -d "$DEPSDIR" ]; then
    [ -z "$BUILD_USER" ] || chown -R "$BUILD_USER" "$DEPSDIR"
    [ -z "$BUILD_GROUP" ] || chgrp -R "$BUILD_GROUP" "$DEPSDIR"
fi
