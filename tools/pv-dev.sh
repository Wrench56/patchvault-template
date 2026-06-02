#!/bin/sh

die() {
    echo "$1"
    exit 1
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
    echo "Usage: pv-dev add-pkg <pkg> <pkgurl> | pv-dev set repo|pkg|pf <path>"
    exit 0
fi

case "$1" in
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
    *)
        die "Unknown command: $1"
        ;;
esac
