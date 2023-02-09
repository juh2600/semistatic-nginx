# syntax=docker/dockerfile:1.3-labs
# inspired by https://www.baeldung.com/ops/docker-cron-job
# and also https://www.cyberciti.biz/faq/linux-unix-shell-check-if-directory-empty/
FROM nginx:alpine
RUN apk update && apk add git
RUN rmdir /srv
RUN rm -rf /usr/share/nginx/html
RUN echo >/tmp/build-crontab-and-stuff.sh '#!/bin/sh'
RUN chmod +x /tmp/build-crontab-and-stuff.sh
# notes to self
# why isn't the following done in RUNs and whatnot? like, y'know, a dockerfile?
# well you see ivan, the idea here is to make the docker-compose.yml as simple
# as possible, so anyone can use this image without having to rewrite it,
# so we don't know at image-build time what repo we'll be pulling. 
# ok, if you're so smart, why are you hard-coding git? what about other systems?
# idgaf i've never used anything else ok
RUN cat <<EOF >>/tmp/build-crontab-and-stuff.sh
# general steps here
# 1. point the nginx html dir to the right dir in our repo (which doesn't actually exist in the filesystem yet)
# 2. set up crontab
# 3. clone the repo
# 3.1 check if repo was cloned ok
# 3.2 if we want a branch, check that out
# 4. if we want to supply an nginx server config, do that
# 4.1 fall back to default config if custom config doesn't work for some reason (FIXME or should we crash early and crash hard?)
# 5. engage cron
# 6. engage nginx
# 7. wait forever so the image doesn't quit immediately, since cron and nginx are daemons and docker watches this script to know when to give up
ln -s /srv/\$DIR /usr/share/nginx/html
[ -z "\$FREQUENCY" ] && export FREQUENCY='0 0 * * *' # pull daily by default
crontab -l | { cat; echo "\$FREQUENCY git -C /srv pull"; } | crontab -
git clone \$REPO /srv
[ "\$(ls -A /srv)" ] || echo >&2 /srv still empty, was \$REPO pulled successfully?
[ -z "\$BRANCH" ] || git -C /srv checkout \$BRANCH
[ -z "\$NGINX_CONF" ] || { # if we asked for a conf file
	[ -e /srv/\$NGINX_CONF ] && { # and if it exists
		mv /etc/nginx/conf.d/default.conf /tmp;
		cp /srv/\$NGINX_CONF /etc/nginx/conf.d/default.conf || {
			mv /tmp/default.conf /etc/nginx/conf.d/;
			echo >/dev/stderr Failed to copy custom nginx rules from /srv/\$NGINX_CONF! Falling back to defaults
		}
		nginx -t && echo Using custom nginx configuration || {
			mv /tmp/default.conf /etc/nginx/conf.d/;
			echo >/dev/stderr Custom nginx rules failed validation! Falling back to defaults
		}
	} || echo >/dev/stderr Custom nginx rules were not found at /srv/\$NGINX_CONF! Falling back to defaults
}
crond -L /dev/stdout -l2
/docker-entrypoint.sh nginx
sleep infinity
EOF
CMD /tmp/build-crontab-and-stuff.sh
