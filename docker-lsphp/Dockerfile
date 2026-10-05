ARG BASEIMAGE=ghcr.io/ntjapps/openlitespeed:base

# Base Image
FROM ${BASEIMAGE} AS base-ols

ARG PHP_VERSION
ARG LS_VERSION
ARG PHP_DETAIL_VERSION

# Install Base PHP (Removed: bz2, calendar, enchant, excimer, ftp, gettext, imap, ldap, lexbor, memcached, pdo_dblib, pspell, readline, snmp, soap, sysvmsg, sysvsem, tidy, xsl)
RUN apt-get install -y ${LS_VERSION} ${LS_VERSION}-common ${LS_VERSION}-curl ${LS_VERSION}-dbg ${LS_VERSION}-dev ${LS_VERSION}-intl ${LS_VERSION}-modules-source ${LS_VERSION}-mysql ${LS_VERSION}-pgsql ${LS_VERSION}-sqlite3 && \
    if apt-cache show ${LS_VERSION}-opcache > /dev/null 2>&1; then apt-get install -y ${LS_VERSION}-opcache; fi && \
    apt-get autoclean -y && \
    ln -sf /usr/local/lsws/${LS_VERSION}/bin/php /usr/bin/php && \
    ln -sf /usr/local/lsws/${LS_VERSION} /usr/local/lsws/lsactive &&\
    chmod a+x /entrypoint.sh && \
    pecl channel-update pecl.php.net

COPY ./php.d/max-file-upload.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/max-file-upload.ini
COPY ./php.d/mem-limit.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/mem-limit.ini

# Check PHP Version
RUN php -v && \
    php -m

FROM base-ols AS base-php-redis

# Install Base PHP Extensions
RUN /usr/bin/pecl install redis && \
    apt-get autoclean -y

COPY ./php.d/20-redis.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-redis.ini

# Check PHP Version
RUN php -v && \
    php -m

FROM base-php-redis AS base-php-mongodb

RUN /usr/bin/pecl install mongodb && \
    apt-get autoclean -y

COPY ./php.d/20-mongodb.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-mongodb.ini

# Check PHP Version
RUN php -v && \
    php -m

FROM base-php-mongodb AS base

COPY ./php.d/20-swoole.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-swoole.ini

RUN apt-get install -y libbrotli-dev && \
    /usr/bin/pecl install swoole || rm -r /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-swoole.ini && \
    apt-get autoclean -y

# Check PHP Version
RUN php -v && \
    php -m

# Target Image
FROM base AS pcov

ARG PCOV_VERSION=1.0.12

# Install PCOV
RUN /usr/bin/pecl install pcov && \
    apt-get autoclean -y

COPY ./php.d/99-pcov.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/99-pcov.ini

# Check PHP Version
RUN php -v && \
    php -m

# Target Image
FROM base AS xdebug

# Install XDEBUG
RUN /usr/bin/pecl install xdebug && \
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
ARG OCI_VERSION=3.4.1

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
    
COPY ./php.d/20-pdo_oci.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-pdo_oci.ini

RUN if [ "${OCI_VERSION}" != "1.0" && "${OCI_VERSION}" != "1" ]; then \
        yes "instantclient,/usr/oracle/instantclient" | pecl install oci8-${OCI_VERSION}; \
        rm -f /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-pdo_oci.ini; \
    else \
        yes "instantclient,/usr/oracle/instantclient" | pecl install oci8; \
        yes "instantclient,/usr/oracle/instantclient" | pecl install pdo_oci || rm -f /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-pdo_oci.ini; \
    fi

COPY ./php.d/20-oci8.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-oci8.ini

# Check PHP Version
RUN php -v && \
    php -m

# Target Image
FROM oci AS oci-pcov

# Install PCOV
RUN /usr/bin/pecl install pcov && \
    apt-get autoclean -y

COPY ./php.d/99-pcov.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/99-pcov.ini

# Check PHP Version
RUN php -v && \
    php -m

# Target Image
FROM oci AS oci-xdebug

# Install XDEBUG
RUN /usr/bin/pecl install xdebug && \
    apt-get autoclean -y

COPY ./php.d/99-xdebug.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/99-xdebug.ini
