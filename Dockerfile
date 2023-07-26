FROM matsumotory/ngx_mruby:master

RUN cd /usr/local/src/ && \
	rm -rf ngx_mruby && \
	git clone https://github.com/matsumotory/ngx_mruby.git

ENV NGINX_CONFIG_OPT_ENV="${NGINX_CONFIG_OPT_ENV} --with-stream --with-stream_ssl_module --with-stream_ssl_preread_module"

RUN cd /usr/local/src/ngx_mruby && \
	sh build.sh && \
	make install

RUN curl -L https://github.com/a8m/envsubst/releases/latest/download/envsubst-`uname -s`-`uname -m` -o envsubst && \
	chmod +x envsubst && \
	mv envsubst /usr/local/bin
	
COPY nginx.conf /usr/local/nginx/conf/nginx.conf

COPY tcp_dynamic_upstream.rb /usr/local/nginx/conf/tcp_dynamic_upstream.rb

CMD ["bash", "-c", "CONF_FILE=$(mktemp /tmp/nginx-conf-XXXXX) && envsubst -no-unset -no-empty -i /usr/local/nginx/conf/nginx.conf > $CONF_FILE && /usr/local/nginx/sbin/nginx -c $CONF_FILE"]