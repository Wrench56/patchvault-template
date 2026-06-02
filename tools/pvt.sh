#!/bin/sh

die() {
    echo "$1"
    exit 1
}

HASH_CMD=""
detect_hashgen() {
    if cksum -a sha256 /dev/null > /dev/null 2>&1; then
        echo "  Found extended cksum(1) binary!"
        HASH_CMD="cksum"
    elif command -v sha256 > /dev/null 2>&1; then
        echo "  Found sha256(1) binary!"
        HASH_CMD="sha256"
    elif digest -a sha256 /dev/null > /dev/null 2>&1; then
        echo "  Found digest(1) binary!"
        HASH_CMD="digest"
    elif openssl dgst -sha256 /dev/null > /dev/null 2>&1; then
        echo "  Found OpenSSL(1) binary!"
        HASH_CMD="openssl"
    else
        die "  Error: Generation of SHA256 distinfo not supported! Please install one of the following tools: extended cksum(1); sha256(1); digest(1); OpenSSL(1)"
    fi
}

gen_hash() {
    in="$1"

    # TODO: Normalize digest and OpenSSL outputs (checks should work nonetheless)
    case "$HASH_CMD" in
        "cksum") cksum -a sha256 "$in" ;;
        "sha256") sha256 "$in" ;;
        "digest") digest -v -a sha256 "$in" ;;
        "openssl") openssl dgst -sha256 "$in" ;;
        *) die "  Error: Impossible state!" ;;
    esac
}

verify_distinfo() {
    distinfo="$1"
    patchset="$2"

    echo "Verifying distinfo..."
    if [ -z "$HASH_CMD" ]; then
        detect_hashgen
    fi

    exp=$(grep -F "SHA256 ($patchset) = " "$distinfo")
    act=$(cd "/tmp" || exit 0; gen_hash "$patchset") 
    if [ "$exp" = "$act" ]; then
        echo "  $patchset: Ok"
    else
        die "  $patchset: FAILED"
    fi

    echo "Verified pkg distinfo!"
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

PATCHSET=""
fetch_patchset() {
    check="$1"
    pkg="$2"

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
    PATCHSET="${patchset_url##*/}"
    echo "Fetching $PATCHSET from $patchset_url..."
    fetch_file "$patchset_url" "/tmp/sets/$PATCHSET"
    
    if [ "$check" -eq 1 ]; then
        echo "Fetching distinfo..."
        distinfo_urlbase="${pkgurl%/*}"
        distinfo_url="$distinfo_urlbase/distinfo"
        distinfo=$(mktemp)
        fetch_file "$distinfo_url" "$distinfo"

        verify_distinfo "$distinfo" "sets/$PATCHSET"
        rm "$distinfo"
    fi

    # Cleanup
    rm "$tmp_index"
}

apply_patch() {
    patchset="$1"

    patch -p0 -N -d "$(pwd)" -i "/tmp/sets/$patchset"
}

if [ "$#" -le 1 ]; then
    echo "$0 - PatchVault Standard Tool"
    echo ""
    echo "Usage: $0 <command> [...]"
    echo ""
    echo "Commands:"
    echo "  fetch (-c/--check) <pkg>   Fetches (and verifies) a package's patchset that matches your PVFLAGS"
    echo "  apply <patchset>           Applies a previously fetched patchset"
    echo "  patch <pkg>                Fetches and applies a package's patchset that matches your PVFLAGS"
    echo ""
    exit 0
fi

cmd="$1"
shift

case "$cmd" in
    fetch)
        check=0

        while [ "$#" -gt 0 ]; do
            case "$1" in
                -c|--check)
                    check=1
                    shift
                    ;;
                --)
                    shift
                    break
                    ;;
                -*)
                    die "Unknown fetch option: $1"
                    ;;
                *)
                    break
                    ;;
            esac
        done

        if [ ! "$#" -gt 0 ]; then
            die "Missing package"
        fi

        mkdir -p "/tmp/sets"
        fetch_patchset "$check" "$1"
        ;;
    apply)
        if [ ! "$#" -gt 0 ]; then
            die "Missing patchset"
        fi
        apply_patch "$1"
        ;;
    patch)
        # Same as fetch --check + apply
        if [ ! "$#" -gt 0 ]; then
            die "Missing package"
        fi

        mkdir -p "/tmp/sets"
        fetch_patchset "1" "$1"
        apply_patch "$PATCHSET"
        ;;
    *)
        die "Unknown command: $cmd"
        ;;
esac
