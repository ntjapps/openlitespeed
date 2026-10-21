[![Build Run](https://github.com/ntj125app/openlitespeed/actions/workflows/image-build.yaml/badge.svg)](https://github.com/ntj125app/openlitespeed/actions/workflows/image-build.yaml)

# What is this repository?

This is customized Openlitespeed repository for use in other application
This repo already apply some of the latest patches and pear / pearl packages for easier setup

## LICENSE

License can be read in [LICENSE](https://github.com/ntj125app/openlitespeed/blob/latest/LICENSE)

## Pinned extension versions

The lsphp images (`docker-lsphp/Dockerfile`) install PECL extensions at pinned versions, set as `ARG`s at the top of the
file. All of them support PHP 8.3 - 8.5. Each pin has a matching `<EXT>_SHA256`: the checksum of the fallback download
(see below), verified with `sha256sum -c` before anything is built.

| ARG | Version | Fallback download (sha256 source) | Notes |
| --- | --- | --- | --- |
| `REDIS_VERSION` / `REDIS_SHA256` | 6.3.0 | GitHub `archive/refs/tags/<ver>.tar.gz` (generated archive, hash stable in practice) | |
| `MONGODB_VERSION` / `MONGODB_SHA256` | 2.5.5 | GitHub release asset `mongodb-<ver>.tgz` (release page shows the digest) | |
| `SWOOLE_VERSION` / `SWOOLE_SHA256` | 6.2.3 | GitHub `archive/refs/tags/v<ver>.tar.gz` (generated archive) | optional: the image is built without swoole if it cannot be installed (a warning is printed) |
| `PCOV_VERSION` / `PCOV_SHA256` | 1.0.12 | GitHub `archive/refs/tags/v<ver>.tar.gz` (generated archive) | pcov / oci-pcov variants |
| `XDEBUG_VERSION` / `XDEBUG_SHA256` | 3.5.3 | `https://xdebug.org/files/xdebug-<ver>.tgz` (hash listed on https://xdebug.org/download/historical) | xdebug / oci-xdebug variants; 3.5.x is the line that supports PHP 8.5 |
| `OCI_VERSION` / `OCI_SHA256` | 3.4.1 | GitHub release asset `oci8-<ver>.tgz` (release page shows the digest) | oci variants; oci8 3.4.x needs PHP 8.2+ (PHP 8.1 would need 3.2.1). `pdo_oci` is not a PECL package and is not installed |

To bump one:
1. Check its PHP support in the extension's `package.xml` (`<php><min>/<max>`).
2. Change the `*_VERSION` default, then download the fallback URL (see the table; the URLs are in the matching `RUN
   pecl-install ...` step) and put its `sha256sum` in `*_SHA256`. Cross-check it against the published checksum where there
   is one (xdebug.org listing, `gh api repos/<owner>/<repo>/releases/tags/<tag> --jq '.assets[].digest'`); for the
   generated GitHub archives, download twice and compare.
3. Build one variant locally or via a manual dispatch from a branch. If one extension needs a different version for one
   PHP version, pass `--build-arg <NAME>_VERSION=... --build-arg <NAME>_SHA256=...` for that matrix entry in
   `.github/workflows/image-build.yaml`.

All installs go through `docker-lsphp/pecl-install.sh`: it retries `pecl install` against pecl.php.net (which regularly
returns 504s) and then falls back to the checksum-verified download above, so a PECL outage does not fail the build
matrix. A checksum mismatch, or a fallback without a checksum, fails the build. `swoole` and `pcov` build in the lsphp
stage with `pkg-config` and `libbrotli-dev`, which are purged afterwards (`debian:13-slim` ships no `pkg-config`).

## Updates

28 Sep 2026
