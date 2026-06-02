#!/bin/sh

die() {
    echo "$1"
    exit 1
}

fetch_file() {
    url="$1"
    dest="$2"
    if command -v curl > /dev/null 2>&1; then
        curl -fsSL -o "$dest" "$url"
    elif command -v wget > /dev/null 2>&1; then
        wget -q -O "$dest" "$url"
    elif command -v fetch > /dev/null 2>&1; then
        fetch -q -o "$dest" "$url"
    elif command -v ftp > /dev/null 2>&1; then
        ftp -o "$dest" "$url"
    else
        die "No HTTP client found"
    fi
}

match_pv_flags() {
    index_file="$1"
    if [ -z "$PVFLAGS" ]; then
        echo "Warning: No PVFLAGS set!" >&2
    fi

    awk -v uf=" $PVFLAGS " '
    {
        ok = 1
        for (i = 2; i <= NF; i++)
            if (index(uf, " " $i " ") == 0) { ok = 0; break }
        if (ok) { print $1; found = 1 }
    }
    END { exit(found ? 0 : 1) }
    ' "$index_file"
}

search_patch_index() {
    pkg="$1"
    if [ -z "$pkg" ]; then
        die "Requested package not given!"
    fi

    if [ -z "$PVREPO" ]; then
        die "PVREPO environment variable was not set!"
    fi

    echo "Fetching root index..."
    tmp_index=$(mktemp)
    fetch_file "$PVREPO" "$tmp_index"
    result=$(grep "^$pkg" "$tmp_index")

    if [ -z "$result" ]; then
        die "No package matches for pkg $pkg"
    fi
    if [ "$(printf "%s", "$result" | wc -l)" -gt 1 ]; then
        echo "Warning: More than one result pkgs found, using first one..."
    fi
    pkgurl="$(echo "$result" | cut -d' ' -f2)"

    echo "Fetching package index from $pkgurl..."
    fetch_file "$pkgurl" "$tmp_index"

    echo "Applying PVFLAGS..."
    matches="$(match_pv_flags "$tmp_index")"
    if [ -z "$matches" ]; then
        echo "No patchset matches flags: $PVFLAGS"
        exit 0
    fi

    if [ "$(printf "%s" "$matches" | wc -l)" -gt 1 ]; then
        echo "Warning: More than patchsets found, using first one..."
    fi

    patchset_url="$(printf "%s" "$matches" | head -n1 | cut -d' ' -f1)"
    patchset="${patchset_url##*/}"
    echo "Fetching $patchset from $patchset_url..."
    fetch_file "$patchset_url" "/tmp/$patchset"
    patch -p0 -N -d "$(pwd)" -i "$patchset"
}

if [ "$#" -eq 0 ]; then
    echo "Usage: pv fetch <pkg>"
    exit 0
fi

case "$1" in
    fetch)
        search_patch_index "$2"
        ;;
    *)
        die "Unknown command: $1"
        ;;
esac
