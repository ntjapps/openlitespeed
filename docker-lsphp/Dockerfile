ARG BASEIMAGE=ghcr.io/ntjapps/openlitespeed:base

# Base Image
FROM ${BASEIMAGE} AS base-ols

ARG PHP_VERSION
ARG LS_VERSION
ARG PHP_DETAIL_VERSION

# Pinned PECL extension versions (all support PHP 8.3 - 8.5). See README "Pinned extension versions".
# Override per PHP version with --build-arg when one of them stops supporting a PHP release.
# *_SHA256 is the sha256 of the fallback download used when pecl.php.net is down (URLs in the RUN steps below).
ARG REDIS_VERSION=6.3.0
ARG REDIS_SHA256=cb8f81df1a275599e4f8ddcfec7e1f65ed1953e6f5673649149fd680ebff4cad
ARG MONGODB_VERSION=2.5.5
ARG MONGODB_SHA256=0eaf84ff709f73183d80597f31ff02937f6aefde01eb895a0aa19334a290cec0
ARG SWOOLE_VERSION=6.2.4
ARG SWOOLE_SHA256=92624681feb1b1311a4ee0fc40080e747b63fc5d0ed988f8e6aa148aac55987f
ARG PCOV_VERSION=1.0.12
ARG PCOV_SHA256=fdd07cad8e2ff42f0c9f095d84aeef11dab0fde7a008805f61883cbcb1b3f12b
ARG XDEBUG_VERSION=3.5.3
ARG XDEBUG_SHA256=f073de91bea046106abf4d6071c963ea71e58571df6ce58948ceca89d121cb2d
ARG OCI_VERSION=3.4.1
ARG OCI_SHA256=c6d612bc750d551dfc15b969346f6a67167f4441f08943adaa3e7fda5d90dd2b

# Retrying PECL installer with a non-pecl.php.net fallback (see the script header)
COPY --chmod=0755 ./pecl-install.sh /usr/local/bin/pecl-install

# Install Base PHP (Removed: bz2, calendar, enchant, excimer, ftp, gettext, imap, ldap, lexbor, memcached, pdo_dblib, pspell, readline, snmp, soap, sysvmsg, sysvsem, tidy, xsl)
RUN apt-get update && apt-get install -y ${LS_VERSION} ${LS_VERSION}-common ${LS_VERSION}-curl ${LS_VERSION}-dbg ${LS_VERSION}-dev ${LS_VERSION}-intl ${LS_VERSION}-modules-source ${LS_VERSION}-mysql ${LS_VERSION}-pgsql ${LS_VERSION}-sqlite3 && \
    if apt-cache show ${LS_VERSION}-opcache > /dev/null 2>&1; then apt-get install -y ${LS_VERSION}-opcache; fi && \
    apt-get autoclean -y && \
    ln -sf /usr/local/lsws/${LS_VERSION}/bin/php /usr/bin/php && \
    ln -sf /usr/local/lsws/${LS_VERSION} /usr/local/lsws/lsactive &&\
    chmod a+x /entrypoint.sh && \
    (pecl channel-update pecl.php.net || echo "WARNING: pecl channel-update failed (pecl.php.net down?), continuing")

COPY ./php.d/max-file-upload.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/max-file-upload.ini
COPY ./php.d/mem-limit.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/mem-limit.ini

# Check PHP Version
RUN php -v && \
    php -m

FROM base-ols AS base-php-redis

# Install Base PHP Extensions
RUN pecl-install redis "${REDIS_VERSION}" "https://github.com/phpredis/phpredis/archive/refs/tags/${REDIS_VERSION}.tar.gz" "${REDIS_SHA256}" && \
    apt-get autoclean -y

COPY ./php.d/20-redis.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-redis.ini

# Check PHP Version
RUN php -v && \
    php -m

FROM base-php-redis AS base-php-mongodb

RUN pecl-install mongodb "${MONGODB_VERSION}" "https://github.com/mongodb/mongo-php-driver/releases/download/${MONGODB_VERSION}/mongodb-${MONGODB_VERSION}.tgz" "${MONGODB_SHA256}" && \
    apt-get autoclean -y

COPY ./php.d/20-mongodb.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-mongodb.ini

# Check PHP Version
RUN php -v && \
    php -m

FROM base-php-mongodb AS base

COPY ./php.d/20-swoole.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-swoole.ini

# swoole is optional: if it cannot be built the ini is dropped and the image ships without it.
# pkg-config is needed by swoole's configure (libbrotlienc check); debian:13-slim no longer ships it.
# pkg-config and libbrotli-dev are build-only and purged afterwards; libbrotli1 (runtime) stays.
RUN apt-get install -y --no-install-recommends pkg-config libbrotli-dev && \
    apt-mark manual libbrotli1 > /dev/null && \
    if FALLBACK_CONFIGURE_ARGS="--enable-brotli" \
       pecl-install swoole "${SWOOLE_VERSION}" "https://github.com/swoole/swoole-src/archive/refs/tags/v${SWOOLE_VERSION}.tar.gz" "${SWOOLE_SHA256}"; then \
        ! ldd "$(php -r 'echo ini_get("extension_dir");')/swoole.so" | grep 'not found'; \
    else \
        echo "WARNING: swoole ${SWOOLE_VERSION} could not be installed, building the image without it" >&2; \
        rm -f /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-swoole.ini; \
    fi && \
    apt-get purge -y pkg-config pkgconf pkgconf-bin libpkgconf3 libbrotli-dev && \
    apt-get autoclean -y

# Check PHP Version
RUN php -v && \
    php -m

# Target Image
FROM base AS pcov

# Install PCOV
RUN FALLBACK_CONFIGURE_ARGS="--enable-pcov" \
    pecl-install pcov "${PCOV_VERSION}" "https://github.com/krakjoe/pcov/archive/refs/tags/v${PCOV_VERSION}.tar.gz" "${PCOV_SHA256}" && \
    apt-get autoclean -y

COPY ./php.d/99-pcov.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/99-pcov.ini

# Check PHP Version
RUN php -v && \
    php -m

# Target Image
FROM base AS xdebug

# Install XDEBUG
RUN pecl-install xdebug "${XDEBUG_VERSION}" "https://xdebug.org/files/xdebug-${XDEBUG_VERSION}.tgz" "${XDEBUG_SHA256}" && \
    apt-get autoclean -y

COPY ./php.d/99-xdebug.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/99-xdebug.ini

# Check PHP Version
RUN php -v && \
    php -m

# Target Image
FROM base AS oci

ARG ORACLE_VERSION=21.23.0.0.0
ARG ORACLE_SIMPLE_VERSION=2123000
ARG ORACLE_ZIP_DIR=instantclient_21_23
# Instant Client 21 has no Linux arm64 build; arm64 images get 19.x, the
# newest line Oracle ships for aarch64. /usr/oracle/instantclient points at
# whichever one was installed.
ARG ORACLE_ARM64_VERSION=19.32.0.0.0
ARG ORACLE_ARM64_SIMPLE_VERSION=1932000
ARG ORACLE_ARM64_ZIP_DIR=instantclient_19_32
ARG TARGETARCH

# Install Oracle Instant Client
# Debian 13 renamed libaio1 to libaio1t64 (libaio.so.1t64); Instant Client links against libaio.so.1.
RUN if apt-cache show libaio1t64 >/dev/null 2>&1; then aio=libaio1t64; else aio=libaio1; fi && \
    apt-get install -y libaio-dev ${aio} unzip && mkdir -p /usr/oracle && \
    for so in /usr/lib/*/libaio.so.1t64; do \
        [ -e "$so" ] && [ ! -e "$(dirname "$so")/libaio.so.1" ] && ln -s "$so" "$(dirname "$so")/libaio.so.1" || true; \
    done && \
    case "${TARGETARCH:-amd64}" in \
        arm64) ic_arch=arm64; ic_ver=${ORACLE_ARM64_VERSION}; ic_simple=${ORACLE_ARM64_SIMPLE_VERSION}; ic_dir=${ORACLE_ARM64_ZIP_DIR} ;; \
        *) ic_arch=x64; ic_ver=${ORACLE_VERSION}; ic_simple=${ORACLE_SIMPLE_VERSION}; ic_dir=${ORACLE_ZIP_DIR} ;; \
    esac && \
    curl https://download.oracle.com/otn_software/linux/instantclient/${ic_simple}/instantclient-basic-linux.${ic_arch}-${ic_ver}dbru.zip --output /usr/oracle/oic.zip && \
    curl https://download.oracle.com/otn_software/linux/instantclient/${ic_simple}/instantclient-sdk-linux.${ic_arch}-${ic_ver}dbru.zip --output /usr/oracle/sdk.zip && \
    cd /usr/oracle && \
    unzip -o oic.zip && \
    unzip -o sdk.zip && \
    ln -sfn /usr/oracle/${ic_dir} /usr/oracle/instantclient && \
    rm -f oic.zip && \
    rm -f sdk.zip && \
    apt-get autoclean -y && \
    echo /usr/oracle/instantclient > /etc/ld.so.conf.d/oracle-instantclient.conf && \
    ldconfig && \
    ! ldd /usr/oracle/instantclient/libclntsh.so | grep 'not found'
    
# oci8 only (pdo_oci is not a PECL package). Fails the build if oci8 cannot be installed.
RUN PECL_ANSWER="instantclient,/usr/oracle/instantclient" \
    pecl-install oci8 "${OCI_VERSION}" "https://github.com/php/pecl-database-oci8/releases/download/v${OCI_VERSION}/oci8-${OCI_VERSION}.tgz" "${OCI_SHA256}"

COPY ./php.d/20-oci8.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-oci8.ini

# Check PHP Version
RUN php -v && \
    php -m

# Target Image
FROM oci AS oci-pcov

# Install PCOV
RUN FALLBACK_CONFIGURE_ARGS="--enable-pcov" \
    pecl-install pcov "${PCOV_VERSION}" "https://github.com/krakjoe/pcov/archive/refs/tags/v${PCOV_VERSION}.tar.gz" "${PCOV_SHA256}" && \
    apt-get autoclean -y

COPY ./php.d/99-pcov.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/99-pcov.ini

# Check PHP Version
RUN php -v && \
    php -m

# Target Image
FROM oci AS oci-xdebug

# Install XDEBUG
RUN pecl-install xdebug "${XDEBUG_VERSION}" "https://xdebug.org/files/xdebug-${XDEBUG_VERSION}.tgz" "${XDEBUG_SHA256}" && \
    apt-get autoclean -y

COPY ./php.d/99-xdebug.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/99-xdebug.ini
