FROM phusion/baseimage:0.9.16

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends radosgw && \
    curl http://bobrik.name/tengine_2.1.0_amd64.deb > /tmp/tengine_2.1.0_amd64.deb && \
    dpkg -i /tmp/tengine_2.1.0_amd64.deb && \
    rm /tmp/tengine_2.1.0_amd64.deb

ADD ./conf/nginx.conf /etc/nginx/conf.d/default.conf
ADD ./services/nginx /etc/service/nginx/run

ADD ./services/radosgw /etc/service/radosgw/run

EXPOSE 80
