# Let's Nginx

*[dockerhub build](https://hub.docker.com/r/smashwilson/lets-nginx/)*

Put browser-valid TLS termination in front of any Dockerized HTTP service with one command.

```bash
docker run --detach \
  --name lets-nginx \
  --link backend:backend \
  --env EMAIL=me@email.com \
  --env DOMAIN=mydomain.horse \
  --env UPSTREAM=backend:8080 \
  --publish 80:80 \
  --publish 443:443 \
  smashwilson/lets-nginx
```

Issues certificates from [letsencrypt](https://letsencrypt.org/), installs them in [nginx](https://www.nginx.com/), and schedules a cron job to reissue them monthly.

:zap: To run unattended, this container accepts the letsencrypt terms of service on your behalf. Make sure that the [subscriber agreement](https://letsencrypt.org/repository/) is acceptable to you before using this container. :zap:

## Prerequisites

Before you begin, you'll need:

 1. A [place to run Docker containers](https://getcarina.com/) with a public IP.
 2. A domain name with an *A record* pointing to your cluster.

## Usage

Launch your backend container and note its name, then launch `smashwilson/lets-nginx` with the following parameters:

 * `--link backend:backend` to link your backend service's container to this one. *(This may be unnecessary depending on Docker's [networking configuration](https://docs.docker.com/engine/userguide/networking/dockernetworks/).)*
 * `-e EMAIL=` your email address, used to register with letsencrypt.
 * `-e DOMAIN=` the domain name.
 * `-e UPSTREAM=` the name of your backend container and the port on which the service is listening.
 * `-p 80:80` and `-p 443:443` so that the letsencrypt client and nginx can bind to those ports on your public interface.
 * `-e STAGING=1` uses the Let's Encrypt *staging server* instead of the production one.
            I highly recommend using this option to double check your infrastructure before you launch a real service.
            Let's Encrypt rate-limits the production server to issuing
            [five certificates per domain per seven days](https://community.letsencrypt.org/t/public-beta-rate-limits/4772/3),
            which (as I discovered the hard way) you can quickly exhaust by debugging unrelated problems!
 * `-v {PATH_TO_CONFIGS}:/configs:ro` specify manual configurations for select domains.  Must be in the form {DOMAIN}.conf to be recognized.

### Using more than one backend service

You can distribute traffic to multiple upstream proxy destinations, chosen by the Host header. This is useful if you have more than one container you want to access with https.

To do so, separate multiple corresponding values in the DOMAIN and UPSTREAM variables separated by a `;`:

```bash
-e DOMAIN="domain1.com;sub.domain1.com;another.domain.net"
-e UPSTREAM="backend:8080;172.17.0.5:60;container:5000"
```

## Caching the Certificates and/or DH Parameters

Since `--link`s don't survive the re-creation of the target container, you'll need to coordinate re-creating
the proxy container. In this case, you can cache the certificates and Diffie-Hellman parameters with the following procedure:

Do this once:

```bash
docker volume create --name letsencrypt
docker volume create --name letsencrypt-backups
docker volume create --name dhparam-cache
```

Then start the container, attaching the volumes you just created:

```bash
docker run --detach \
  --name lets-nginx \
  --link backend:backend \
  --env EMAIL=me@email.com \
  --env DOMAIN=mydomain.horse \
  --env UPSTREAM=backend:8080 \
  --publish 80:80 \
  --publish 443:443 \
  --volume letsencrypt:/etc/letsencrypt \
  --volume letsencrypt-backups:/var/lib/letsencrypt \
  --volume dhparam-cache:/cache \
  smashwilson/lets-nginx
```

## Adjusting Nginx configuration

The entry point of this image processes the `nginx.conf` file in `/templates` and places the result in `/etc/nginx/nginx.conf`. Additionally, the file `/templates/vhost.sample.conf` will be processed once for each `;`-delimited pair of values in `$DOMAIN` and `$UPSTREAM`. The result of each will be placed at `/etc/nginx/vhosts/${DOMAINVALUE}.conf`.

The following variable substitutions are made while processing all of these files:

* `${DOMAIN}`
* `${UPSTREAM}`

For example, to adjust `nginx.conf`, create that file in your new image directory with the [baseline content](templates/nginx.conf) and desired modifications. Within your `Dockerfile` *ADD* this file and it will be used to create the nginx configuration instead.

```docker
FROM smashwilson/lets-nginx

ADD nginx.conf /templates/nginx.conf
```


## Example of usage with docker registry

```bash
sudo mkdir -p /volumes
sudo chown $USER:$USER /volumes
export DOMAIN_REGISTRY=registry.rokubun.synology.me
export UPSTREAM_REGISTRY=registry:5000


export DOMAIN=${DOMAIN_REGISTRY}
export UPSTREAM=${UPSTREAM_REGISTRY}
export DOMAIN_ADMIN_EMAIL="alex.lopez@rokubun.cat"


export DOMAIN_MEDEA=medea.rokubun.synology.me
export MEDEA_UPSTREAM=192.168.1.250:80
docker-compose up -d
```

Create user in httpasswd

```
docker run --entrypoint htpasswd registry:2 -Bbn alex _413x_ >> /volumes/registry/auth/htpasswd
```


## Examples of running lets-nginx with some services
```
docker run -d --name registry --restart=always \
  -p 5000:5000 \
  -v $(pwd)/volumes/registry/var/lib/registry:/var/lib/registry \
  -v $(pwd)/volumes/registry/auth:/auth \
  -e REGISTRY_HTTP_HOST=https://${DOMAIN_REGISTRY} \
  -e REGISTRY_AUTH_HTPASSWD_REALM=${DOMAIN_REGISTRY} \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  registry:2

docker run --entrypoint htpasswd registry:2 -Bbn alex _413x_ >> $(pwd)/volumes/registry/auth/htpasswd

docker run --name lets-nginx --restart=always \
  --link registry:registry \
  -p 80:80 \
  -p 443:443 \
  -v /volumes/lets-nginx/cache:/cache \
  -v /volumes/lets-nginx/etc/letsencrypt:/etc/letsencrypt \
  -e EMAIL=${DOMAIN_ADMIN_EMAIL} \
  -e DOMAIN=${DOMAIN_REGISTRY} \
  -e UPSTREAM=registry:5000 \
  xocru/rpi-lets-nginx


docker run --name lets-nginx --restart=always \
  --link registry:registry \
  -p 80:80 \
  -p 443:443 \
  -v $(pwd)/volumes/lets-nginx/cache:/cache \
  -v $(pwd)/volumes/lets-nginx/etc/letsencrypt:/etc/letsencrypt \
  -e EMAIL=${DOMAIN_ADMIN_EMAIL} \
  -e DOMAIN=${DOMAIN} \
  -e UPSTREAM=${UPSTREAM} \
  rpi-lets-nginx


docker run --name lets-nginx  --rm --restart=always \
  -p 80:80 \
  -p 443:443 \
  -v $(pwd)/volumes/lets-nginx/cache:/cache \
  -v $(pwd)/volumes/lets-nginx/etc/letsencrypt:/etc/letsencrypt \
  -e EMAIL=${DOMAIN_ADMIN_EMAIL} \
  -e DOMAIN=${DOMAINS} \
  -e UPSTREAM=${UPSTREAMS} \
  local/rpi-lets-nginx




export MEDEA_DOMAIN=medea.rokubun.synology.me
export MEDEA_UPSTREAM=192.168.1.250
export DOMAIN_ADMIN_EMAIL="alex.lopez@rokubun.cat"
export DOMAINS="${MEDEA_DOMAIN}"
export UPSTREAMS="${MEDEA_UPSTREAM}"
  docker run --name medea-nginx  --restart=always \
  -p 80:80 \
  -p 443:443 \
  -v $(pwd)/volumes/lets-nginx/cache:/cache \
  -v $(pwd)/volumes/lets-nginx/etc/letsencrypt:/etc/letsencrypt \
  -e EMAIL=${DOMAIN_ADMIN_EMAIL} \
  -e DOMAIN=${DOMAINS} \
  -e UPSTREAM=${UPSTREAMS} local/lets-rpi-nginx

```