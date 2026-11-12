# Base pinned by digest (multi-arch index): `docker buildx imagetools inspect debian:13-slim`, copy the top-level "Digest:".
# Dependabot (docker, target dev) opens a PR when the digest moves.
FROM debian:13-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

# Optional build args (CI passes them from the repo variables OLS_VERSION / OLS_REPO_SCRIPT_SHA256):
#   OLS_VERSION                 exact apt version of the openlitespeed package (as listed by
#                               `apt-cache madison openlitespeed`). Empty = latest from the LiteSpeed repo.
#                               When set, lsup.sh is skipped because it upgrades OLS to the latest release.
#   OLS_REPO_SCRIPT_SHA256      expected SHA-256 of https://repo.litespeed.sh. Empty = not verified.
# TODO(security): LiteSpeed does not publish a checksum for repo.litespeed.sh, and the script itself fetches
# the apt signing key and repo definition over plain HTTP. Pinning the script (OLS_REPO_SCRIPT_SHA256) therefore
# does NOT protect against a man-in-the-middle on those follow-up downloads. Real fix (follow-up): vendor the
# LiteSpeed apt key with a verified fingerprint in this repo and add the source with `signed-by=`, then drop
# repo.litespeed.sh. Until then the script is only downloaded to a file (never piped into bash), fetched over
# HTTPS only (including redirects) and run with `bash -e`.
# wget stays installed on purpose: LiteSpeed's repo helper scripts call it; verify with a build before removing.
ARG OLS_VERSION=""
ARG OLS_REPO_SCRIPT_SHA256=""

RUN rm -f /entrypoint.sh && \
    apt-get update && apt-get upgrade -y && apt-get autoremove -y && apt-get install -y curl wget && \
    curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 -o /tmp/repo.litespeed.sh https://repo.litespeed.sh && \
    if [ -n "${OLS_REPO_SCRIPT_SHA256}" ]; then echo "${OLS_REPO_SCRIPT_SHA256}  /tmp/repo.litespeed.sh" | sha256sum -c -; fi && \
    bash -e /tmp/repo.litespeed.sh && \
    rm -f /tmp/repo.litespeed.sh && \
    apt-get autoclean -y && \
    apt-get install -y "openlitespeed${OLS_VERSION:+=${OLS_VERSION}}" && \
    if [ -z "${OLS_VERSION}" ]; then /usr/local/lsws/admin/misc/lsup.sh; fi && \
    # WebAdmin: the shipped httpd_config.conf sets disableWebAdmin 1; as a second layer the package's admin listener
    # (default *:7080) is bound to loopback so it is never reachable from the network even if that flag is ignored.
    # The build fails if an admin listener still binds a non-loopback address.
    if [ -f /usr/local/lsws/admin/conf/admin_config.conf ]; then \
        sed -i -E 's/^([[:space:]]*address[[:space:]]+)(\*|0\.0\.0\.0|\[::\]):7080/\1127.0.0.1:7080/' /usr/local/lsws/admin/conf/admin_config.conf && \
        ! grep -E '^[[:space:]]*address[[:space:]]+(\*|0\.0\.0\.0|\[::\]):[0-9]+' /usr/local/lsws/admin/conf/admin_config.conf; \
    fi && \
    mv /usr/local/lsws/conf /usr/local/lsws/conf-disabled

COPY ./lsws-conf /usr/local/lsws/conf

COPY ./entrypoint.sh /entrypoint.sh

RUN chown lsadm:nogroup -R /usr/local/lsws/conf && chmod o-rwx -R /usr/local/lsws/conf && \
    chmod a+x /entrypoint.sh && chmod a+rwx -R /usr/local/lsws/logs

WORKDIR /var/www/vhosts/localhost

ENTRYPOINT ["/entrypoint.sh"]
