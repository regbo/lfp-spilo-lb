FROM matsumotory/ngx_mruby:master

ADD https://github.com/matsumotory/ngx_mruby/archive/refs/heads/master.zip /tmp/ngx_mruby.zip

RUN cd /usr/local/src/ && \
	rm -rf ngx_mruby && \
    unzip /tmp/ngx_mruby.zip -d /tmp/ngx_mruby && \
	mv /tmp/ngx_mruby/ngx_mruby-master ngx_mruby && \
    rm /tmp/ngx_mruby.zip

ENV NGINX_CONFIG_OPT_ENV="${NGINX_CONFIG_OPT_ENV} --with-stream --with-stream_ssl_module --with-stream_ssl_preread_module"

RUN cd /usr/local/src/ngx_mruby && \
	sh build.sh && \
	make install && \
    rm -rf /usr/local/src/ngx_mruby

RUN curl -L https://github.com/a8m/envsubst/releases/latest/download/envsubst-`uname -s`-`uname -m` -o envsubst && \
	chmod +x envsubst && \
	mv envsubst /usr/local/bin


COPY nginx.conf /usr/local/nginx/conf
COPY tcp_dynamic_upstream.rb /usr/local/nginx/hook

CMD ["bash", "-c", "CONF_FILE=$(mktemp /tmp/nginx-conf-XXXXX) && envsubst -no-unset -no-empty -i /usr/local/nginx/conf/nginx.conf > $CONF_FILE && /usr/local/nginx/sbin/nginx -c $CONF_FILE"]