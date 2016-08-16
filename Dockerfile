FROM openresty/openresty:centos

# Example docker file for stomrpath-nginx. 
# You can spin this up easily with the example file and the following commands:
# $ docker build -t stormpath-nginx .
# $ docker run -p 8080:8080 \
# -e STORMPATH_APPLICATION_HREF \
# -e STORMPATH_CLIENT_APIKEY_ID \
# -e STORMPATH_CLIENT_APIKEY_SECRET \
# stormpath-nginx

ENV STORMPATH_CLIENT_APIKEY_ID     ""
ENV STORMPATH_CLIENT_APIKEY_SECRET ""
ENV STORMPATH_APPLICATION_HREF     ""


RUN yum install -y git \
  && yum -y clean all

RUN /usr/local/openresty/luajit/bin/luarocks install stormpath-nginx

ADD example.nginx.conf /etc/nginx/nginx.conf


ENTRYPOINT ["/usr/local/openresty/nginx/sbin/nginx", "-c", "/etc/nginx/nginx.conf", "-g", "daemon off;"]


EXPOSE "8080"
