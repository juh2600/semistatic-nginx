# syntax=docker/dockerfile:1.3-labs
# inspired by https://www.baeldung.com/ops/docker-cron-job
# and also https://www.cyberciti.biz/faq/linux-unix-shell-check-if-directory-empty/
FROM nginx:alpine
RUN apk update && apk add git
RUN rmdir /srv
RUN ln -s /usr/share/nginx/html /srv
RUN rm /srv/*
WORKDIR /srv
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
crontab -l | { cat; echo "\$FREQUENCY git -C /srv pull"; } | crontab -
git clone \$REPO /srv
[ "\$(ls -A /srv)" ] || echo >&2 /srv still empty, was \$REPO pulled successfully?
crond -L /dev/stdout -l2
/docker-entrypoint.sh nginx
sleep infinity
EOF
CMD /tmp/build-crontab-and-stuff.sh
