# syntax=docker/dockerfile:1.3-labs
# inspired by https://www.baeldung.com/ops/docker-cron-job
# and also https://www.cyberciti.biz/faq/linux-unix-shell-check-if-directory-empty/
FROM nginx:alpine
RUN apk update && apk add git

RUN rm -rf /srv
RUN rm -rf /usr/share/nginx/html
#RUN mv /etc/nginx/conf.d/default.conf /tmp/nginx-default.conf
RUN mv /etc/nginx/nginx.conf /tmp/nginx-default.conf

RUN echo >/tmp/cronjob.sh '#!/bin/sh'
RUN echo >/tmp/docker-entrypoint.sh '#!/bin/sh'

RUN chmod +x /tmp/cronjob.sh
RUN chmod +x /tmp/docker-entrypoint.sh

# notes to self
# why isn't the following done in RUNs and whatnot? like, y'know, a dockerfile?
# well you see ivan, the idea here is to make the docker-compose.yml as simple
# as possible, so anyone can use this image without having to rewrite it,
# so we don't know at image-build time what repo we'll be pulling. 
# ok, if you're so smart, why are you hard-coding git? what about other systems?
# idgaf i've never used anything else ok
RUN cat <<EOF >>/tmp/cronjob.sh
git -C /srv pull
nginx -s reload
EOF
RUN cat <<EOF >>/tmp/docker-entrypoint.sh
# general steps here
# 1. fill default values if they weren't supplied
# 2. grab any build deps
# 3. set up symlinks to nginx conf and html dir
# 4. clone, checkout
# 5. build (if we have a build step)
# 6. set up cronjob to build (if we have a build step)
# 7. commit cronjob to crontab
# 8. run crond and nginx
# 9. sleep forever so docker doesn't quit immediately

[ -z "\$FREQUENCY" ] && export FREQUENCY='0 0 * * *' # pull daily by default
[ -z "\$NGINX_CONF" ] && {
	export NGINX_CONF='/tmp/nginx-default.conf' # default to default server config
} || {
	export NGINX_CONF=/srv/\$NGINX_CONF
}

[ -z "\$APK_DEPENDS" ] || {
	apk update
	apk add \$APK_DEPENDS
}

ln -s /srv/\$DIR /usr/share/nginx/html
ln -s \$NGINX_CONF /etc/nginx/nginx.conf
#[ -z "\$NGINX_MODULES" ] || {
#	mv /etc/nginx/nginx.conf /tmp
#	for module in \$NGINX_MODULES
#	do
#		echo load_module modules/\$module.so\; | tee -a /etc/nginx/nginx.conf
#	done
#	cat /tmp/nginx.conf >> /etc/nginx/nginx.conf
#}

git clone \$REPO /srv
[ "\$(ls -A /srv)" ] || echo >&2 /srv still empty, was \$REPO pulled successfully?
[ -z "\$BRANCH" ] || git -C /srv checkout \$BRANCH

[ -z "\$BUILD" ] || {
	\$BUILD
	echo cd /srv >> /tmp/cronjob.sh
	echo \$BUILD >> /tmp/cronjob.sh
}

crontab -l | { cat; echo "\$FREQUENCY /tmp/cronjob.sh"; } | crontab -

crond -L /dev/stdout -l2
/docker-entrypoint.sh nginx
sleep infinity
EOF

WORKDIR /srv
CMD /tmp/docker-entrypoint.sh
