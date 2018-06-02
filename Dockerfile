FROM lsiobase/alpine:3.7

# global environment settings 
ENV PLATFORM_ARCH="amd64" 
ENV RCLONE_VERSION="current"

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV S6_KEEP_ENV=1

RUN \
 echo "**** install packages ****" && \
 apk add --no-cache wget curl bash findutils gawk bc unzip && \
 echo "**** install rclone ****" && \
 cd tmp && \ 
    wget -q https://downloads.rclone.org/rclone-${RCLONE_VERSION}-linux-${PLATFORM_ARCH}.zip && \
    unzip /tmp/rclone-${RCLONE_VERSION}-linux-${PLATFORM_ARCH}.zip && \
    mv /tmp/rclone-*-linux-${PLATFORM_ARCH}/rclone /usr/bin && \
    apk add --no-cache --repository http://nl.alpinelinux.org/alpine/edge/community \ 
    shadow && \ 
 echo "**** clean up ****" && \
    rm -rf \ 
        /tmp/* \ 
        /var/tmp/* \ 
        /var/cache/apk/* && \
 echo "**** file gen ****" && \
    mkdir -p /move /config /json && \ 
    touch /var/lock/rclone.lock

# add local files
COPY root/ /

# ports and volumes
VOLUME /move /config /json