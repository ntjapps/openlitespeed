[![Build Run](https://github.com/ntj125app/openlitespeed/actions/workflows/image-build.yaml/badge.svg)](https://github.com/ntj125app/openlitespeed/actions/workflows/image-build.yaml)

# What is this repository?

This is customized Openlitespeed repository for use in other application
This repo already apply some of the latest patches and pear / pearl packages for easier setup

## LICENSE

License can be read in [LICENSE](https://github.com/ntj125app/openlitespeed/blob/latest/LICENSE)

## Pinned extension versions

The lsphp images (`docker-lsphp/Dockerfile`) install PECL extensions at pinned versions, set as `ARG`s at the top of the
file. All of them support PHP 8.3 - 8.5.

| ARG | Version | Notes |
| --- | --- | --- |
| `REDIS_VERSION` | 6.3.0 | |
| `MONGODB_VERSION` | 2.5.5 | |
| `SWOOLE_VERSION` | 6.2.3 | optional: the image is built without swoole if it cannot be installed (a warning is printed) |
| `PCOV_VERSION` | 1.0.12 | pcov / oci-pcov variants |
| `XDEBUG_VERSION` | 3.5.3 | xdebug / oci-xdebug variants; 3.5.x is the line that supports PHP 8.5 |
| `OCI_VERSION` | 3.4.1 | oci variants; oci8 3.4.x needs PHP 8.2+ (PHP 8.1 would need 3.2.1). `pdo_oci` is not a PECL package and is not installed |

To bump one: check its PHP support in the extension's `package.xml` (`<php><min>/<max>`), change the `ARG` default, and
build one variant locally or via a manual dispatch from a branch. If one extension needs a different version for one PHP
version, pass `--build-arg <NAME>_VERSION=...` for that matrix entry in `.github/workflows/image-build.yaml`.

All installs go through `docker-lsphp/pecl-install.sh`: it retries `pecl install` against pecl.php.net (which regularly
returns 504s) and then falls back to the extension's release tarball (xdebug.org / GitHub), so a PECL outage does not
fail the build matrix. The fallback URL is derived from the same `*_VERSION` arg; when bumping, check that URL pattern
still exists. `swoole` and `pcov` build in the lsphp stage with `pkg-config` and `libbrotli-dev`, which are purged
afterwards (`debian:13-slim` ships no `pkg-config`).

## Updates

28 Sep 2026
