#!/bin/sh

die() {
    echo "$1"
    exit 1
}

lint_index() {
    index="$(pwd)/index"
    if [ ! -f "$index" ]; then
        die "Error: No index found in root folder: $(pwd)"
    fi

    duplist="$(cut -d' ' -f1 "$index" | uniq -d)"
    if [ -n "$duplist" ]; then
        echo "Error: Multiple pkgurl-s found for pkg(s):"
        die "$duplist"
    fi
}

if [ "$#" -eq 0 ]; then
    echo "Usage: pv-ci lint-index|all"
    exit 0
fi

case "$1" in
    lint-index)
        lint_index
        ;;
    all)
        lint_index
        ;;
    *)
        die "Unknown command: $1"
        ;;
esac
