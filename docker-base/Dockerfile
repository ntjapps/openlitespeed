FROM debian:13-slim

# Optional build args:
#   OLS_VERSION                 exact apt version of the openlitespeed package (as listed by
#                               `apt-cache madison openlitespeed`). Empty = latest from the LiteSpeed repo.
#                               When set, lsup.sh is skipped because it upgrades OLS to the latest release.
#   OLS_REPO_SCRIPT_SHA256      expected SHA-256 of https://repo.litespeed.sh. Empty = not verified.
# TODO(security): LiteSpeed does not publish a checksum for repo.litespeed.sh, so it is downloaded to a file
# (never piped into bash) and run with `bash -e`, but its content is not pinned. Once a pinned hash or a
# vendored apt key + signed-by source list is available, set OLS_REPO_SCRIPT_SHA256 (or replace the script).
ARG OLS_VERSION=""
ARG OLS_REPO_SCRIPT_SHA256=""

RUN rm -f /entrypoint.sh && \
    apt-get update && apt-get upgrade -y && apt-get autoremove -y && apt-get install -y curl wget && \
    curl -fsSL --proto '=https' --tlsv1.2 -o /tmp/repo.litespeed.sh https://repo.litespeed.sh && \
    if [ -n "${OLS_REPO_SCRIPT_SHA256}" ]; then echo "${OLS_REPO_SCRIPT_SHA256}  /tmp/repo.litespeed.sh" | sha256sum -c -; fi && \
    bash -e /tmp/repo.litespeed.sh && \
    rm -f /tmp/repo.litespeed.sh && \
    apt-get autoclean -y && \
    apt-get install -y "openlitespeed${OLS_VERSION:+=${OLS_VERSION}}" && \
    if [ -z "${OLS_VERSION}" ]; then /usr/local/lsws/admin/misc/lsup.sh; fi && \
    mv /usr/local/lsws/conf /usr/local/lsws/conf-disabled

COPY ./lsws-conf /usr/local/lsws/conf

COPY ./entrypoint.sh /entrypoint.sh

RUN chown lsadm:nogroup -R /usr/local/lsws/conf && chmod o-rwx -R /usr/local/lsws/conf && \
    chmod a+x /entrypoint.sh && chmod a+rwx -R /usr/local/lsws/logs

WORKDIR /var/www/vhosts/localhost

ENTRYPOINT ["/entrypoint.sh"]
