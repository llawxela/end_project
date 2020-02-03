FROM debian:jessie
# note: we use jessie instead of wheezy because our deps are easier to get here

# runtime dependencies
# (packages are listed alphabetically to ease maintenence)
RUN apt-get update && apt-get install -y --no-install-recommends \
		fontconfig-config \
		fonts-dejavu-core \
		geoip-database \
		init-system-helpers \
		libarchive-extract-perl \
		libexpat1 \
		libfontconfig1 \
		libfreetype6 \
		libgcrypt11 \
		libgd3 \
		libgdbm3 \
		libgeoip1 \
		libgpg-error0 \
		libjbig0 \
		libjpeg8 \
		liblog-message-perl \
		liblog-message-simple-perl \
		libmodule-pluggable-perl \
		libpng12-0 \
		libpod-latex-perl \
		libssl1.0.0 \
		libterm-ui-perl \
		libtext-soundex-perl \
		libtiff5 \
		libvpx1 \
		libx11-6 \
		libx11-data \
		libxau6 \
		libxcb1 \
		libxdmcp6 \
		libxml2 \
		libxpm4 \
		libxslt1.1 \
		perl \
		perl-modules \
		rename \
		sgml-base \
		ucf \
		xml-core \
	&& rm -rf /var/lib/apt/lists/*

# see http://nginx.org/en/pgp_keys.html
RUN gpg --keyserver pgp.mit.edu --recv-key \
	A09CD539B8BB8CBE96E82BDFABD4D3B3F5806B4D \
	4C2C85E705DC730833990C38A9376139A524C53E \
	B0F4253373F8F6F510D42178520A9993A1C052F8 \
	65506C02EFC250F1B7A3D694ECF0E90B2C172083 \
	7338973069ED3F443F4D37DFA64FD5B17ADB39A8 \
	6E067260B83DCF2CA93C566F518509686C7E5E82 \
	573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62

ENV NGINX_VERSION 1.7.4

# All our runtime and build dependencies, in alphabetical order (to ease maintenance)
RUN buildDeps=" \
		ca-certificates \
		curl \
		gcc \
		libc-dev-bin \
		libc6-dev \
		libexpat1-dev \
		libfontconfig1-dev \
		libfreetype6-dev \
		libgd-dev \
		libgd2-dev \
		libgeoip-dev \
		libice-dev \
		libjbig-dev \
		libjpeg8-dev \
		liblzma-dev \
		libpcre3-dev \
		libperl-dev \
		libpng12-dev \
		libpthread-stubs0-dev \
		libsm-dev \
		libssl-dev \
		libssl-dev \
		libtiff5-dev \
		libvpx-dev \
		libx11-dev \
		libxau-dev \
		libxcb1-dev \
		libxdmcp-dev \
		libxml2-dev \
		libxpm-dev \
		libxslt1-dev \
		libxt-dev \
		linux-libc-dev \
		make \
		manpages-dev \
		x11proto-core-dev \
		x11proto-input-dev \
		x11proto-kb-dev \
		xtrans-dev \
		zlib1g-dev \
	"; \
	apt-get update && apt-get install -y --no-install-recommends $buildDeps && rm -rf /var/lib/apt/lists/* \
	&& curl -SL "http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz" -o nginx.tar.gz \
	&& curl -SL "http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc" -o nginx.tar.gz.asc \
	&& gpg --verify nginx.tar.gz.asc \
	&& mkdir -p /usr/src/nginx \
	&& tar -xvf nginx.tar.gz -C /usr/src/nginx --strip-components=1 \
	&& rm nginx.tar.gz* \
	&& cd /usr/src/nginx \
	&& ./configure \
		--user=www-data \
		--group=www-data \
		--prefix=/usr/local/nginx \
		--conf-path=/etc/nginx.conf \
		--http-log-path=/proc/self/fd/1 \
		--error-log-path=/proc/self/fd/2 \
		--with-http_addition_module \
		--with-http_auth_request_module \
		--with-http_dav_module \
		--with-http_geoip_module \
		--with-http_gzip_static_module \
		--with-http_image_filter_module \
		--with-http_perl_module \
		--with-http_realip_module \
		--with-http_spdy_module \
		--with-http_ssl_module \
		--with-http_stub_status_module \
		--with-http_sub_module \
		--with-http_xslt_module \
		--with-ipv6 \
		--with-mail \
		--with-mail_ssl_module \
		--with-pcre-jit \
	&& make -j"$(nproc)" \
	&& make install \
	&& cd / \
	&& rm -r /usr/src/nginx \
	&& chown -R www-data:www-data /usr/local/nginx \
	&& { \
		echo; \
		echo '# stay in the foreground so Docker has a process to track'; \
		echo 'daemon off;'; \
	} >> /etc/nginx.conf \
	&& apt-get purge -y --auto-remove $buildDeps

ENV PATH /usr/local/nginx/sbin:$PATH
WORKDIR /usr/local/nginx/html

# TODO USER www-data

EXPOSE 80
CMD ["nginx"]


FROM php:%%PHP_VERSION%%-%%VARIANT%%

# persistent dependencies
RUN apk add --no-cache \
# in theory, docker-entrypoint.sh is POSIX-compliant, but priority is a working, consistent image
		bash \
# BusyBox sed is not sufficient for some of our sed expressions
		sed \
# Ghostscript is required for rendering PDF previews
		ghostscript

# install the PHP extensions we need (https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		freetype-dev \
		imagemagick-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd --with-freetype --with-jpeg; \
	docker-php-ext-install -j "$(nproc)" \
		bcmath \
		exif \
		gd \
		mysqli \
		opcache \
		zip \
	; \
	pecl install imagick-3.4.4; \
	docker-php-ext-enable imagick; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --virtual .wordpress-phpexts-rundeps $runDeps; \
	apk del .build-deps

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini
# https://wordpress.org/support/article/editing-wp-config-php/#configure-error-logging
RUN { \
# https://www.php.net/manual/en/errorfunc.constants.php
# https://github.com/docker-library/wordpress/issues/420#issuecomment-517839670
		echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
		echo 'display_errors = Off'; \
		echo 'display_startup_errors = Off'; \
		echo 'log_errors = On'; \
		echo 'error_log = /dev/stderr'; \
		echo 'log_errors_max_len = 1024'; \
		echo 'ignore_repeated_errors = On'; \
		echo 'ignore_repeated_source = Off'; \
		echo 'html_errors = Off'; \
	} > /usr/local/etc/php/conf.d/error-logging.ini
%%VARIANT_EXTRAS%%
VOLUME /var/www/html

ENV WORDPRESS_VERSION %%WORDPRESS_VERSION%%
ENV WORDPRESS_SHA1 %%WORDPRESS_SHA1%%

RUN set -ex; \
	curl -o wordpress.tar.gz -fSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz"; \
	echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c -; \
# upstream tarballs include ./wordpress/ so this gives us /usr/src/wordpress
	tar -xzf wordpress.tar.gz -C /usr/src/; \
	rm wordpress.tar.gz; \
	chown -R www-data:www-data /usr/src/wordpress

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["%%CMD%%"]

