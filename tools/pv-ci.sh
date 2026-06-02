#!/bin/sh

die() {
    echo "$1"
    exit 1
}

url_exists() {
    url="$1"

    if command -v curl >/dev/null 2>&1; then
        curl -fsIL --max-time 10 "$url" >/dev/null 2>&1
    elif command -v wget >/dev/null 2>&1; then
        wget -q --spider -T 10 "$url"
    elif command -v fetch >/dev/null 2>&1; then
        fetch -q -T 10 "$url" >/dev/null
    else
        die "No HTTP client found"
    fi
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

verify_urls() {
    echo "Verifying URLs..."
    if ! url_exists "https://google.com/"; then
        die "Not connected to network! (Or Google is down?!)"
    fi
    echo "  Established baseline"

    failed=0
    while read -r pkg url; do
        if url_exists "$url"; then
            continue
        fi

        failed=1
        echo "  Error: Invalid URL: $url for package $pkg"
    done < "index"

    if [ "$failed" -eq 1 ]; then
        die "URL verification failed!"
    fi

    echo "Verified index URLs!"
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

    case "$HASH_CMD" in
        "cksum") cksum -a sha256 "$in" ;;
        "sha256") sha256 "$in" ;;
        "digest") digest -v -a sha256 "$in" ;;
        "openssl") openssl dgst -sha256 "$in" ;;
        *) die "  Error: Impossible state!" ;;
    esac
}


verify_distinfo() {
    echo "Verifying distinfos..."
    if [ -z "$HASH_CMD" ]; then
        detect_hashgen
    fi

    for pkg in pkgs/*; do
        if [ ! -e "$pkg" ]; then
            continue
        fi

        echo "  Checking distinfo for: $pkg..."
        (
            cd "$pkg" || die "  Error: Could not cd(1) into $pkg"
            if [ ! -f "distinfo" ]; then
                echo "    Warning: distinfo for pkg does not exist"
                exit 0
            fi
            while IFS= read -r line; do
                file=$(echo "$line" | cut -f 2 -d ' ' | tr -d '()')
                act=$(gen_hash "$file")
                if [ "$act" = "$line" ]; then
                    echo "    $file: Ok"
                else
                    die "    $file: FAILED"
                fi
            done < "distinfo"
        )
    done
    echo "Verified pkg distinfos"
}

append_distinfo() {
    in="$1"
    out="$2"

    # TODO: Normalize digest and OpenSSL outputs (checks should work nonetheless)
    case "$HASH_CMD" in
        "cksum") cksum -a sha256 "$in" >> "$out" ;;
        "sha256") sha256 "$in" >> "$out" ;;
        "digest") digest -v -a sha256 "$in" >> "$out" ;;
        "openssl") openssl dgst -sha256 "$in" >> "$out" ;;
        *) die "  Error: Impossible state!" ;;
    esac
}

regen_distinfo() {
    echo "Regenerating distinfos..."
    if [ -z "$HASH_CMD" ]; then
        detect_hashgen
    fi

    for pkg in pkgs/*; do
        if [ ! -e "$pkg" ]; then
            continue
        fi

        echo "  Generating distinfo for: $pkg..."
        (
            cd "$pkg" || die "  Error: Could not cd(1) into $pkg"
            rm -f "distinfo"
            find "." -type f -print | while IFS= read -r file; do
                append_distinfo "${file#'./'}" "distinfo"
            done
        )
    done
    echo "Regenerated pkg distinfos"
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
    echo "Usage: pv-ci lint-index|verify-urls|verify-distinfo|regen-distinfo|refresh-index <baseurl>|build-patchsets <baseurl>|all <baseurl>"
    exit 0
fi

case "$1" in
    lint-index)
        lint_index
        ;;
    verify-urls)
        verify_urls
        ;;
    verify-distinfo)
        verify_distinfo
        ;;
    refresh-index)
        refresh_index "$2"
        ;;
    regen-distinfo)
        regen_distinfo
        ;;
    build-patchsets)
        build_patchsets "$2"
        ;;
    all)
        lint_index
        verify_urls
        verify_distinfo
        refresh_index "$2"
        build_patchsets "$2"
        regen_distinfo
        ;;
    *)
        die "Unknown command: $1"
        ;;
esac
