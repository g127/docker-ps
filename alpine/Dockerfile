FROM g127/alpine-glibc:3.12.3

LABEL maintainer="gg  <guogang1984@gmail.com>"

# Runing scripts in alpine
RUN echo -e ' ===> Runing scripts in alpine' `cat /etc/alpine-release` \
    && mkdir -p /opt && chmod 777 /opt \
    && TSINGHUA_MIRROR=https://mirrors.tuna.tsinghua.edu.cn \
    # setting apk mirror
    # && sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories \
    && apk upgrade --update \
    # install tzdata
    && apk add tzdata && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" > /etc/timezone \
    # install openresty runtime
    && apk add --no-cache \
        gd \
        geoip \
        libgcc \
        libxslt \
        zlib \
        bash \
        libmaxminddb \
    # create a docker-entrypoint.d directory
    &&  mkdir -p /opt/docker-entrypoint.d \
    # && apk del curl zip \
    &&  rm -rf /tmp/* && rm -rf /var/cache/apk/*

# install supervisor
RUN echo "install supervisor" \
    && apk add --update supervisor=4.2.1-r0 --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main 

# fixed x11 font miss
# RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && \
#     apk upgrade --update && \
#     apk add fontconfig freetype && \
#     apk add --update ttf-dejavu && \
#     fc-cache --force

# add jdk1.8.0_202 maven gradle tomcat /opt/docker-entrypoint.d
COPY --from=g127/java:8_jdk_unlimited-alpine /opt/ /opt/
# add openresty bin
COPY --from=g127/ngx:1.19.3.1-2-alpine /usr/local/openresty /usr/local/openresty
# add openresty configuration
COPY --from=g127/ngx:1.19.3.1-2-alpine /usr/local/openresty/nginx/conf /opt/nginx/conf
# add GeoIP
COPY --from=g127/ngx:1.19.3.1-2-alpine /usr/local/share/GeoIP /usr/local/share/GeoIP

# env
ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    JAVA_HOME=/opt/jdk \
    MAVEN_HOME=/opt/maven \
    TOMCAT_HOME=/opt/tomcat \
    CATALINA_HOME=/opt/tomcat \
    CATALINA_TMPDIR=/tmp/java/tmp \
    CATALINA_OUT=/dev/null \
    PATH=${PATH}:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin \
    PATH=${PATH}:/opt/jdk/bin:/opt/tomcat/bin:/opt/maven/bin:/opt/gradle/bin  \
    QUIET_LOGS=" " \
    SWITCH_RUN=ps 

# 拷贝文件
COPY docker-entrypoint.d/ /opt/docker-entrypoint.d/
#拷贝
COPY docker-entrypoint.sh /opt/

# 启动
ENTRYPOINT ["/opt/docker-entrypoint.sh"]

# Use SIGQUIT instead of default SIGTERM to cleanly drain requests
STOPSIGNAL SIGQUIT

# build and test
# docker build -f alpine/Dockerfile -t g127/ps:test .
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
#    --link db-redis3-1:redis2 \
#    --net=app-net \
#    g127/ps:test
#
#
# docker tag g127/ps:test g127/ps:20210204-alpine
# docker push g127/ps:20210204-alpine

