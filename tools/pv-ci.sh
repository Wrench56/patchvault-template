#!/bin/sh

die() {
    echo "$1"
    exit 1
}

lint_index() {
    index="$(pwd)/index"
    if [ ! -f "$index" ]; then
        echo "Warning: No index found in root folder: $(pwd)"
        return
    fi

    duplist="$(cut -d' ' -f1 "$index" | sort | uniq -d)"
    if [ -n "$duplist" ]; then
        echo "Error: Multiple pkgurl-s found for pkg(s):"
        die "$duplist"
    fi
}

refresh_index() {
    baseurl="$1"

    echo "Refreshing root index"
    touch "index"
    for pkg in pkgs/*; do
        if [ ! -e "$pkg" ]; then
            continue
        fi

        pkgname="${pkg#pkgs/}"
        if ! grep -q "^$pkgname " "index"; then
            echo "  New package detected: $pkgname"
            echo "$pkgname $baseurl/pkgs/$pkg/patchsets" >> "index"
        fi
    done

    sort -u -o "index" "index"
    echo "Root index refreshed!"
}

add_patchset() {
    baseurl="$1"
    ps="$2"
    index="$3"

    echo "Adding patchset to patchsets index"
    echo "$baseurl/$ps $FLAGS" >> "$index"
    sort -u -o "$index" "$index"
}

build_patchset() {
    baseurl="$1"
    psconf="$2"

    # shellcheck disable=SC1090
    . "$psconf"
 
    pkgdir="$(dirname -- "$psconf")"
    ps="$pkgdir/sets/$NAME.patch"

    mkdir -p "$pkgdir/sets"
    printf "===> Assembled by PatchVault\nSource: %s\n\n%s\n" "$baseurl/$psconf" "$DESC" > "$ps"

    echo "Creating patchset $ps"
    printf '%s\n' "$PATCHES" | while IFS= read -r patchname; do
        if [ -z "$patchname" ]; then
            continue
        fi

        patch="$pkgdir/patches/$patchname"
        if [ ! -f "$patch" ]; then
            echo "Warning: patch $patch not found!"
            continue
        fi
        echo "  Bundling patch: $patch"
        echo "" >> "$ps"
        cat "$patch" >> "$ps"
    done

    add_patchset "$baseurl" "$ps" "$pkgdir/patchsets"
    echo ""
}

build_patchsets() {
    baseurl="$1"
    for psconf in pkgs/*/*.conf; do
        if [ ! -e "$psconf" ]; then
            continue
        fi

        build_patchset "$baseurl" "$psconf"       
    done
}

if [ "$#" -eq 0 ]; then
    echo "Usage: pv-ci lint-index|refresh-index <baseurl>|build-patchsets <baseurl>|all <baseurl>"
    exit 0
fi

case "$1" in
    lint-index)
        lint_index
        ;;
    refresh-index)
        refresh_index "$2"
        ;;
    build-patchsets)
        build_patchsets "$2"
        ;;
    all)
        lint_index
        refresh_index "$2"
        build_patchsets "$2"
        ;;
    *)
        die "Unknown command: $1"
        ;;
esac
