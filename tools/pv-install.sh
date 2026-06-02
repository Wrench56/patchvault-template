#!/bin/sh

die() {
    echo "$1"
    exit 1
}

fetch_file() {
    url="$1"
    out="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time 30 -o "$out" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T 30 -O "$out" "$url"
    elif command -v fetch >/dev/null 2>&1; then
        fetch -q -T 30 -o "$out" "$url"
    else
        die "No HTTP client found"
    fi
}

install_sh() {
    path="$1"

    chmod +x "$path"

    # TODO: Ugly, non-POSIX way... is there POSIX way though?
    mkdir -p "$HOME/.local/bin"
    mv "$path" "$HOME/.local/bin/${path##*/}"
}

if [ "$#" -eq 0 ]; then
    echo "Usage: pv-install [-d/--dev] [-c/--ci] -b/--baseurl <baseurl>"
    exit 0
fi

std=0
dev=0
ci=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        -b|--baseurl)
            [ "$#" -ge 2 ] || die "$1 requires <baseurl>"
            baseurl="$2"
            shift 2
            ;;
        --baseurl=*)
            baseurl=${1#--baseurl=}
            shift
            ;;
        -s|--standard)
            std=1
            shift
            ;;
        -d|--dev)
            dev=1
            shift
            ;;
        -c|--ci)
            ci=1
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            die "Unknown option: $1"
            ;;
        *)
            break
            ;;
    esac
done

mkdir -p "/tmp/"
baseurl=${baseurl%/}
if [ "$std" -eq 1 ]; then   
    tmp="/tmp/pv"
    fetch_file "$baseurl/tools/pv.sh" "$tmp"
    install_sh "$tmp"
fi
if [ "$dev" -eq 1 ]; then
    tmp="/tmp/pv-dev"
    fetch_file "$baseurl/tools/pv-dev.sh" "$tmp"
    install_sh "$tmp"
fi
if [ "$ci" -eq 1 ]; then
    tmp="/tmp/pv-ci"
    fetch_file "$baseurl/tools/pv-ci.sh" "$tmp"
    install_sh "$tmp"
fi
