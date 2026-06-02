#!/bin/sh

die() {
    echo "$1"
    exit 1
}

need_patch_env() {
    [ -n "$PVREPO_PATH" ] || die "PVREPO_PATH is not set"
    [ -n "$PVPKG" ] || die "PVPKG is not set"
    [ -n "$PVPATCHFILE" ] || die "PVPATCHFILE is not set"
}

init_pkg() {
    pkg="$1"
    if [ -z "$pkg" ]; then
        die "No pkg provided"
    fi
    [ -n "$PVREPO_PATH" ] || die "PVREPO_PATH is not set"

    mkdir -p "$PVREPO_PATH/pkgs/$pkg"
    mkdir "$PVREPO_PATH/pkgs/$pkg/sets"
    mkdir "$PVREPO_PATH/pkgs/$pkg/patches"
}

add_new_pkg() {
    pkg="$1"
    pkgurl="$2"
    if [ -z "$pkg" ]; then
        die "No pkg provided"
    fi
    if [ -z "$pkgurl" ]; then
        die "No pkgurl provided"
    fi

    index="$(pwd)/index"
    if [ ! -f "$index" ]; then
        die "No index found in root folder: $(pwd)"
    fi

    if grep -q "^$pkg " "$index"; then
        die "Error: pkg $pkg already in index"
    fi

    echo "$pkg $pkgurl" >> "$index"
    sort -u -o "$index" "$index"
}

if [ "$#" -eq 0 ]; then
    echo "Usage: pv-dev add-pkg <pkg> <pkgurl> | pv-dev set repo|pkg|pf <path> | pv-dev diff <orig> <changed> | pv-dev vdiff <file>"
    exit 0
fi

case "$1" in
    init-pkg)
        init_pkg "$2"
        ;;
    add-pkg)
        add_new_pkg "$2" "$3"
        ;;
    set)
        case "$2" in
            repo)
                export PVREPO_PATH="$3"
                echo "export PVREPO_PATH=$PVREPO_PATH"
                ;;
            pkg)
                export PVPKG="$3"
                echo "export PVPKG=$PVPKG"
                ;;
            pf)
                export PVPATCHFILE="$3"
                echo "export PVPATCHFILE=$PVPATCHFILE"
                ;;
            *)
                die "Unknown variable to set: $2"
                ;;
        esac
        ;;
    diff)
        need_patch_env
        diff -u "$2" "$3" > "$PVREPO_PATH/pkgs/$PVPKG/patches/$PVPATCHFILE"
        ;;
    vdiff)
        need_patch_env
        diff -u "$2" - > "$PVREPO_PATH/pkgs/$PVPKG/patches/$PVPATCHFILE"
        ;;
    *)
        die "Unknown command: $1"
        ;;
esac
