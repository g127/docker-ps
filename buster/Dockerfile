# FROM debian:buster-slim
#FROM python:3.8.7-slim-buster
FROM g127/ngx:1.19.3.1-2-buster

LABEL maintainer="gg  <guogang1984@gmail.com>"


# add jdk1.8.0_202 maven gradle tomcat /opt/docker-entrypoint.d
COPY --from=g127/java:8_jdk_unlimited-tomcat9-buster /opt/ /opt/

RUN echo 'run script' \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       bash \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* 

# env
ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    JAVA_HOME=/opt/jdk \
    MAVEN_HOME=/opt/maven \
    TOMCAT_HOME=/opt/tomcat \
    CATALINA_HOME=/opt/tomcat \
    CATALINA_TMPDIR=/tmp/java/tmp \
    CATALINA_OUT=/dev/null \
    PATH=${PATH}:/opt/jdk/bin:/opt/tomcat/bin:/opt/maven/bin:/opt/gradle/bin  \
    QUIET_LOGS=" " \
    SWITCH_RUN=tomcat 

# 拷贝文件
COPY docker-entrypoint.d/ /opt/docker-entrypoint.d/

# 启动文件
COPY docker-entrypoint.sh /opt/

ENTRYPOINT ["/opt/docker-entrypoint.sh"]

# Use SIGQUIT instead of default SIGTERM to cleanly drain requests
STOPSIGNAL SIGQUIT

# build and test
# docker build -f buster/Dockerfile -t g127/ps:test .
#
# # SWITCH_RUN 测试  ps nginx app tomcat init bash
# docker run -it --rm --name test \
#    -e QUIET_LOGS=" " \
#    -e SWITCH_RUN=ps \
#    -e NGX_CONFIGURE_PATH=/opt/nginx/conf   \
#    -e NGX_VHOST=env     \
#    -e NGX_VHOST_PATH=/opt/nginx/conf/vhosts/http/     \
#    -e NGX_VHOST_MODE=http_proxy_http    \
#    -e NGX_VHOST_LISTEN=80     \
#    -e NGX_VHOST_SERVER_NAME="app.com localhost "    \
#    -e NGX_VHOST_WWW_DOMAIN=app.com     \
#    -e NGX_VHOST_PROXY_1_LOCATION=/    \
#    -e NGX_VHOST_PROXY_1_PASS=http://127.0.0.1:8080/     \
#    -e NGX_VHOST_PROXY_1_COOKIE_PATH_OLD=/app     \
#    -e NGX_VHOST_PROXY_1_COOKIE_PATH_NEW=/     \
#    -e NGX_VHOST_PROXY_2_LOCATION=/arcgis/     \
#    -e NGX_VHOST_PROXY_2_PASS=http://111.47.18.22:10033/arcgis/     \
#    -e NGX_VHOST_PROXY_2_COOKIE_PATH_OLD=/app     \
#    -e NGX_VHOST_PROXY_2_COOKIE_PATH_NEW=/     \
#    -e NGX_VHOST_RESOURCE_1_LOCATION=/h5     \
#    -e NGX_VHOST_RESOURCE_1_SUBPATH=h5     \
#    -e CATALINA_REDIS_HOSTS=redis3:6379 \
#    -e CATALINA_APPBASE=/opt/tomcat/webapps \
#    -p 80:80 \
#    -p 8080:8080  \
#    -v $(pwd)/docker-entrypoint.sh:/opt/docker-entrypoint.sh \
#    -v /Users/gg/DevProjectFiles/ws-my-github/docker-alpine-java/docker-entrypoint.d/tomcat:/opt/docker-entrypoint.d/tomcat \
#    -v /Users/gg/DevProjectFiles/ws-my-github/docker-alpine-openresty/conf:/opt/nginx/conf \
#    -v /Users/gg/DevProjectFiles/ws-my-github/docker-alpine-openresty/conf/tpl/ngx_tpl.sh:/opt/docker-entrypoint.d/ngx_tpl.sh \
#    --link redis:redis3 \
#    --net=app-net \
#    g127/ps:test
#
# docker run -it --rm --name test \
#    -e QUIET_LOGS=" " \
#    -e SWITCH_RUN=ps \
#    -e NGX_CONFIGURE_PATH=/opt/nginx/conf   \
#    -e NGX_VHOST=env     \
#    -e NGX_VHOST_PATH=/opt/nginx/conf/vhosts/http/     \
#    -e NGX_VHOST_MODE=http_proxy_http    \
#    -e NGX_VHOST_LISTEN=80     \
#    -e NGX_VHOST_SERVER_NAME="app.com localhost "    \
#    -e NGX_VHOST_WWW_DOMAIN=app.com     \
#    -e NGX_VHOST_PROXY_1_LOCATION=/    \
#    -e NGX_VHOST_PROXY_1_PASS=http://127.0.0.1:8080/     \
#    -e NGX_VHOST_PROXY_1_COOKIE_PATH_OLD=/app     \
#    -e NGX_VHOST_PROXY_1_COOKIE_PATH_NEW=/     \
#    -e NGX_VHOST_PROXY_2_LOCATION=/arcgis/     \
#    -e NGX_VHOST_PROXY_2_PASS=http://111.47.18.22:10033/arcgis/     \
#    -e NGX_VHOST_PROXY_2_COOKIE_PATH_OLD=/app     \
#    -e NGX_VHOST_PROXY_2_COOKIE_PATH_NEW=/     \
#    -e NGX_VHOST_RESOURCE_1_LOCATION=/h5     \
#    -e NGX_VHOST_RESOURCE_1_SUBPATH=h5     \
#    -e CATALINA_REDIS_HOSTS=redis3:6379 \
#    -e CATALINA_APPBASE=/opt/tomcat/webapps \
#    -p 80:80 \
#    -p 8080:8080  \
#    -v $(pwd)/docker-entrypoint.sh:/opt/docker-entrypoint.sh \
#    -v /Users/gg/DevProjectFiles/ws-my-github/docker-alpine-java/docker-entrypoint.d/tomcat-setup.sh:/opt/docker-entrypoint.d/tomcat-setup.sh \
#    -v /Users/gg/DevProjectFiles/ws-my-github/docker-alpine-java/docker-entrypoint.d/tomcat:/opt/docker-entrypoint.d/tomcat \
#    -v /Users/gg/DevProjectFiles/ws-my-github/docker-alpine-openresty/conf:/opt/nginx/conf \
#    -v /Users/gg/DevProjectFiles/ws-my-github/docker-alpine-openresty/conf/tpl/ngx_tpl.sh:/opt/docker-entrypoint.d/ngx_tpl.sh \
#    --link db-redis3-1:redis3 \
#    --net=app-net \
#    g127/ps:test
#
# docker tag g127/ps:test g127/ps:20210801-buster
# docker push g127/ps:20210801-buster
