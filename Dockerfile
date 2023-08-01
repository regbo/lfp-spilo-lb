FROM caddy:builder AS builder

RUN xcaddy build \
    --with github.com/mholt/caddy-l4

FROM caddy:latest

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

RUN apk add --no-cache bash consul-template jq

RUN wget https://github.com/a8m/envsubst/releases/download/v1.2.0/envsubst-`uname -s`-`uname -m` -O envsubst && \
    chmod +x envsubst && \
    mv envsubst /usr/local/bin

COPY run_caddy /run_caddy
RUN chmod +x /run_caddy

COPY caddy.config.template.json /caddy.config.template.json

CMD ["/run_caddy"]