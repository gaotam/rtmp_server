ARG NGINX_VERSION=1.23.1
ARG NGINX_RTMP_VERSION=1.2.11

##############################
# Build the NGINX-build image.
FROM alpine:3.16.1 as build-nginx
ARG NGINX_VERSION
ARG NGINX_RTMP_VERSION
ARG MAKEFLAGS="-j4"

RUN apk add --no-cache \
  build-base \
  gcc \
  linux-headers \
  make \
  openssl \
  openssl-dev \
  pcre \
  pcre-dev \
  zlib-dev
  
WORKDIR /tmp

# Get nginx source.
RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
  tar zxf nginx-${NGINX_VERSION}.tar.gz && \
  rm nginx-${NGINX_VERSION}.tar.gz

# Get nginx-rtmp module.
RUN wget https://github.com/winshining/nginx-http-flv-module/archive/refs/tags/v${NGINX_RTMP_VERSION}.tar.gz && \
  tar zxf v${NGINX_RTMP_VERSION}.tar.gz && \
  rm v${NGINX_RTMP_VERSION}.tar.gz

WORKDIR /tmp/nginx-${NGINX_VERSION}

RUN \
  ./configure \
  --prefix=/usr/local/nginx \
  --add-module=/tmp/nginx-http-flv-module-${NGINX_RTMP_VERSION} \
  --conf-path=/etc/nginx/nginx.conf \
  --with-threads \
  --with-file-aio \
  --with-http_ssl_module \
  --with-debug \
  --with-http_stub_status_module \
  --with-cc-opt="-Wimplicit-fallthrough=0" && \
  make && \
  make install

# Cleanup.
RUN rm -rf /var/cache/* /tmp/*

##########################
# Build the release image.
FROM alpine:3.16.1
LABEL MAINTAINER Bui Hoang <mynamebvh@gmail.com>
# Set default ports.
ENV HTTP_PORT 80
ENV HTTPS_PORT 443
ENV RTMP_PORT 1935

RUN apk add --no-cache \
  gettext \
  ca-certificates \
  openssl \
  pcre \
  curl

COPY --from=build-nginx /usr/local/nginx /usr/local/nginx
COPY --from=build-nginx /etc/nginx /etc/nginx

# Add NGINX path, config and static files.
ENV PATH "${PATH}:/usr/local/nginx/sbin"
COPY nginx.conf /etc/nginx/nginx.conf.template
RUN mkdir -p /opt/data && mkdir /www
RUN mkdir -p /tmp/record/live /tmp/record/hls
RUN chown -R nobody:root /tmp/record

EXPOSE 1935
EXPOSE 80

CMD envsubst "$(env | sed -e 's/=.*//' -e 's/^/\$/g')" < \
  /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && \
  nginx