FROM phusion/baseimage:0.9.16

RUN echo deb http://ppa.launchpad.net/eric-freeyoung/tengine/ubuntu precise main >> /etc/apt/sources.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8DB19DE2 && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y radosgw tengine

ADD ./conf/nginx.conf /etc/nginx/sites-available/default
ADD ./services/nginx /etc/service/nginx/run

ADD ./services/radosgw /etc/service/radosgw/run

EXPOSE 80
