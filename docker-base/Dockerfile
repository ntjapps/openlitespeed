FROM debian:13-slim

RUN apt-get update && apt-get upgrade -y && apt-get autoremove -y && apt-get install -y curl wget && \
    wget -O - https://repo.litespeed.sh | bash && \
    apt-get autoclean -y && \
    rm /entrypoint.sh || true && \
    apt-get install -y openlitespeed && \
    /usr/local/lsws/admin/misc/lsup.sh && \
    mv /usr/local/lsws/conf /usr/local/lsws/conf-disabled

COPY ./lsws-conf /usr/local/lsws/conf

COPY ./entrypoint.sh /entrypoint.sh

RUN chown lsadm:nogroup -R /usr/local/lsws/conf && chmod o-rwx -R /usr/local/lsws/conf && \
    chmod a+x /entrypoint.sh && chmod a+rwx -R /usr/local/lsws/logs

WORKDIR /var/www/vhosts/localhost

ENTRYPOINT ["/entrypoint.sh"]
