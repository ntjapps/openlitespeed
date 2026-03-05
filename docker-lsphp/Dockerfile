ARG BASEIMAGE=ghcr.io/ntjapps/openlitespeed:base

# Base Image
FROM ${BASEIMAGE} AS base-ols

ARG PHP_VERSION
ARG LS_VERSION
ARG PHP_DETAIL_VERSION

# Install Base PHP
RUN apt-get install -y ${LS_VERSION} ${LS_VERSION}-common ${LS_VERSION}-curl ${LS_VERSION}-dbg ${LS_VERSION}-dev ${LS_VERSION}-imap ${LS_VERSION}-intl ${LS_VERSION}-ldap ${LS_VERSION}-modules-source ${LS_VERSION}-mysql ${LS_VERSION}-pgsql ${LS_VERSION}-pspell ${LS_VERSION}-snmp ${LS_VERSION}-sqlite3 ${LS_VERSION}-sybase ${LS_VERSION}-tidy && \
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

FROM base-php-mongodb AS base-php-excimer

RUN /usr/bin/pecl install excimer && \
    apt-get autoclean -y

COPY ./php.d/20-excimer.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-excimer.ini

# Check PHP Version
RUN php -v && \
    php -m

FROM base-php-excimer AS base-php-memcached

RUN apt-get install -y libmemcached-dev zlib1g-dev pkg-config && \
    /usr/bin/pecl install memcached && \
    apt-get autoclean -y

COPY ./php.d/20-memcached.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-memcached.ini

# Check PHP Version
RUN php -v && \
    php -m

FROM base-php-memcached AS base

COPY ./php.d/20-swoole.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-swoole.ini

RUN apt-get install -y libbrotli-dev && \
    /usr/bin/pecl install swoole || rm -r /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-swoole.ini && \
    apt-get autoclean -y

# Check PHP Version
RUN php -v && \
    php -m

# Target Image
FROM base AS pcov

ARG PCOV_VERSION=1.0.11

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

ARG ORACLE_VERSION=21.15.0.0.0
ARG ORACLE_SIMPLE_VERSION=2115000
ARG ORACLE_ZIP_DIR=instantclient_21_15
ARG OCI_VERSION=3.4.0

# Install Oracle Instant Client
RUN apt-get install -y libaio-dev libaio1 unzip && mkdir -p /usr/oracle && \
    curl https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_SIMPLE_VERSION}/instantclient-basic-linux.x64-${ORACLE_VERSION}dbru.zip --output /usr/oracle/oic.zip && \
    curl https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_SIMPLE_VERSION}/instantclient-sdk-linux.x64-${ORACLE_VERSION}dbru.zip --output /usr/oracle/sdk.zip && \
    cd /usr/oracle && \
    unzip oic.zip && \
    unzip sdk.zip && \
    rm -f oic.zip && \
    rm -f sdk.zip && \
    apt-get autoclean -y && \
    echo /usr/oracle/${ORACLE_ZIP_DIR} > /etc/ld.so.conf.d/oracle-instantclient.conf && \
    ldconfig
    
COPY ./php.d/20-pdo_oci.ini /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-pdo_oci.ini

RUN if [ "${OCI_VERSION}" != "1.0" && "${OCI_VERSION}" != "1" ]; then \
        yes "instantclient,/usr/oracle/${ORACLE_ZIP_DIR}" | pecl install oci8-${OCI_VERSION}; \
        rm -f /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-pdo_oci.ini; \
    else \
        yes "instantclient,/usr/oracle/${ORACLE_ZIP_DIR}" | pecl install oci8; \
        yes "instantclient,/usr/oracle/${ORACLE_ZIP_DIR}" | pecl install pdo_oci || rm -f /usr/local/lsws/${LS_VERSION}/etc/php/${PHP_VERSION}/mods-available/20-pdo_oci.ini; \
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
