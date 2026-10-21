#!/bin/sh
# Install a pinned PECL extension, surviving pecl.php.net outages.
#
# Usage: pecl-install <name> <version> [fallback-url sha256]
#   PECL_ANSWER   optional answer fed to pecl's configure prompts (e.g. oci8's instantclient path)
#   FALLBACK_CONFIGURE_ARGS configure flags for a source-archive fallback (e.g. --enable-pcov)
#   PECL_ATTEMPTS number of pecl.php.net attempts before falling back (default 4)
#
# 1. `pecl install <name>-<version>` with retry + backoff (pecl.php.net regularly returns
#    504s; a REST hiccup is not a reason to fail a 40-job build matrix).
# 2. If pecl.php.net stays unavailable and a fallback URL is given, download that archive and
#    install it from disk. The URL is either a ready-made PECL release tarball (package.xml at
#    the archive root, installed with `pecl install <file>`) or a plain GitHub source archive,
#    which is built with phpize/configure/make (extra configure flags in FALLBACK_CONFIGURE_ARGS).
#    The download is verified against the given sha256 before anything is extracted or built;
#    a mismatch (or a fallback URL without a sha256) fails the install.
# Fails (non-zero) when the extension .so is not present afterwards.
set -eu

name=${1:?usage: pecl-install <name> <version> [fallback-url sha256]}
version=${2:?usage: pecl-install <name> <version> [fallback-url sha256]}
fallback=${3:-}
fallback_sha256=${4:-}
attempts=${PECL_ATTEMPTS:-4}
ext_dir=$(php -r 'echo ini_get("extension_dir");')

run_pecl() {
    if [ -n "${PECL_ANSWER:-}" ]; then
        yes "${PECL_ANSWER}" | pecl install "$1"
    else
        pecl install "$1" </dev/null
    fi
}

installed() {
    [ -f "${ext_dir}/${name}.so" ]
}

i=1
while [ "$i" -le "$attempts" ]; do
    if run_pecl "${name}-${version}" && installed; then
        exit 0
    fi
    echo "pecl-install: ${name}-${version} failed via pecl.php.net (attempt ${i}/${attempts})" >&2
    pecl clear-cache >/dev/null 2>&1 || true
    if [ "$i" -lt "$attempts" ]; then
        sleep $((i * 15))
    fi
    i=$((i + 1))
done

if [ -z "$fallback" ]; then
    echo "pecl-install: ${name}-${version} failed and no fallback URL was given" >&2
    exit 1
fi

if [ -z "$fallback_sha256" ]; then
    echo "pecl-install: refusing fallback download without a sha256" >&2
    exit 1
fi

echo "pecl-install: falling back to ${fallback}" >&2
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -fsSL --proto '=https' --proto-redir '=https' --retry 5 --retry-all-errors --retry-delay 5 \
    -o "${work}/src.tgz" "$fallback"
if ! echo "${fallback_sha256}  ${work}/src.tgz" | sha256sum -c -; then
    echo "pecl-install: sha256 mismatch for ${fallback} (expected ${fallback_sha256})" >&2
    exit 1
fi
mkdir "${work}/x"
tar -xzf "${work}/src.tgz" -C "${work}/x"
if [ -f "${work}/x/package.xml" ]; then
    cp "${work}/src.tgz" "${work}/${name}-${version}.tgz"
    run_pecl "${work}/${name}-${version}.tgz"
else
    php_bindir=$(dirname "$(readlink -f "$(command -v php)")")
    srcdir=$(find "${work}/x" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    cd "$srcdir"
    "${php_bindir}/phpize"
    # shellcheck disable=SC2086
    ./configure --with-php-config="${php_bindir}/php-config" ${FALLBACK_CONFIGURE_ARGS:-}
    make -j2
    make install
fi
installed || { echo "pecl-install: ${name}.so missing after fallback install" >&2; exit 1; }
