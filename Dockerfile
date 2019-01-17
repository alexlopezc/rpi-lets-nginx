FROM xocru/rpi-nginx:1.14-alpine
# Base don the work from Ash Wilson <smashwilson@gmail.com>
LABEL author="Alex Lopez <alexlopezcruces@gmail.com>"


RUN [ "cross-build-start" ]

#We need to install bash to easily handle arrays
# in the entrypoint.sh script
RUN apk add --update bash \
  certbot \
  openssl openssl-dev ca-certificates \
  && rm -rf /var/cache/apk/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

# used for webroot reauth
RUN mkdir -p /etc/letsencrypt/webrootauth

COPY entrypoint.sh /opt/entrypoint.sh
ADD templates /templates

# There is an expose in nginx:alpine image
# EXPOSE 80 443
RUN [ "cross-build-end" ]

ENTRYPOINT ["/opt/entrypoint.sh"]
