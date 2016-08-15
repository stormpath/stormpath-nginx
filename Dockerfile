FROM openresty/openresty:centos
#
#  Example Docker configuration
#

ENV STORMPATH_CLIENT_APIKEY_ID     ""
ENV STORMPATH_CLIENT_APIKEY_SECRET ""
ENV STORMPATH_APPLICATION_HREF     ""


RUN yum install -y git \
  && yum -y clean all

RUN /usr/local/openresty/luajit/bin/luarocks install stormpath-nginx

ADD example.nginx.conf /etc/nginx/nginx.conf


ENTRYPOINT ["/usr/local/openresty/nginx/sbin/nginx", "-c", "/etc/nginx/nginx.conf", "-g", "daemon off;"]


EXPOSE "8080"
