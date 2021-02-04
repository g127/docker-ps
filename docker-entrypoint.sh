#!/usr/bin/env bash
# Created by guogang on 16/09/2017

set -e

if [ -z "${QUIET_LOGS:-}" ]; then
    exec 3>&1
else
    exec 3>/dev/null
fi

function log() {
    echo >&3 "$(date +'%Y-%m-%d %H:%M:%S%z') [INFO] - $@"
}

function err() {
    echo >&2 "$(date +'%Y-%m-%d %H:%M:%S%z') [ERRO] - $@"
}

# 初始化安装脚本
function initScripts() {
    log "================================================================================"
    log "initScripts"
    # ================================================================================
    # 执行前的准备脚本
    # ================================================================================
    OPT_ENTRYPOINT_DIR=${OPT_ENTRYPOINT_DIR:-/opt/docker-entrypoint.d/}
    if /usr/bin/find ${OPT_ENTRYPOINT_DIR} -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read v; then
        log "$0: ${OPT_ENTRYPOINT_DIR} is not empty, will attempt to perform configuration"

        log "$0: Looking for shell scripts in ${OPT_ENTRYPOINT_DIR}"
        find ${OPT_ENTRYPOINT_DIR} -follow -type f -print | sort -n | while read -r f; do
            case "$f" in
                *.sh)
                    if [ -x "$f" ]; then
                        log "$0: Launching $f";
                        "$f"
                    else
                        # warn on shell scripts without exec bit
                        log "$0: Ignoring $f, not executable";
                    fi
                    ;;
                # *) log "$0: Ignoring  $f";;
                *) ;;
            esac
        done

        log "$0: Configuration complete; ready for start up"
    else
        log "$0: No files found in ${OPT_ENTRYPOINT_DIR}, skipping configuration"
    fi

}

function configureOpenresty() {
    # # 定义模版位置
    # export TPL_PATH=/opt/nginx/conf
    # # 生成模版逻辑
    # /opt/nginx/conf/tpl/generate.sh 

    # nginx conf 目录位置
    NGX_CONFIGURE_PATH=${NGX_CONFIGURE_PATH:-/usr/local/openresty/nginx/conf}

    # NGX_CONFIGURE_PATH 变量存在，且conf目录中存在 tpl/ngx_tpl.sh（生成模版逻辑） 文件
    if [[ "${NGX_CONFIGURE_PATH}" != "" ]] && [[ -f ${NGX_CONFIGURE_PATH}/tpl/ngx_tpl.sh ]]; then
        if [[ "${QUIET_LOGS:-}" == "" ]]; then
            ${NGX_CONFIGURE_PATH}/tpl/ngx_tpl.sh
        else
            ${NGX_CONFIGURE_PATH}/tpl/ngx_tpl.sh >/dev/null 2>&1
        fi
    fi

    # 辅助配置目录
    if [[ -f ${NGX_CONFIGURE_PATH}/tpl/ngx_tpl.sh ]] && [[ ! -d /DevProjectFiles/ws-root/www/proxy_cache ]]; then
        mkdir -p  /DevProjectFiles/ws-root/www/proxy_cache
        chmod 777 /DevProjectFiles/ws-root/www/proxy_cache
    fi 

    # NGX_CONFIGURE_PATH 变量存在，且conf目录中存在 tpl/generate.sh（生成模版逻辑） 文件
    if [[ "${NGX_CONFIGURE_PATH}" != "" ]] && [[ -f ${NGX_CONFIGURE_PATH}/tpl/generate.sh ]]; then
        export TPL_PATH=${NGX_CONFIGURE_PATH}
        if [[ "${QUIET_LOGS:-}" == "" ]]; then
            ${NGX_CONFIGURE_PATH}/tpl/generate.sh
        else
            ${NGX_CONFIGURE_PATH}/tpl/generate.sh >/dev/null 2>&1
        fi
    fi

}

function configureApp() {
    # ================================================================================
    # 执行前的准备脚本，部分环境变量
    # ================================================================================
    mkdir -p /tmp/web/tmp.java
    # JVM_ARGS_OPTS
    if [ "${JVM_ARGS_OPTS}" == "" ]; then
        JVM_ARGS_OPTS="-Djava.io.tmpdir=/tmp/web/tmp.java -Djava.security.egd=file:/dev/./urandom -Duser.timezone=GMT+08"
        # log "JVM_ARGS_OPTS not provided, default JVM_ARGS_OPTS=${JVM_ARGS_OPTS}."
    fi
    # JVM_PERFORMANCE_OPTS
    if [ "${JVM_PERFORMANCE_OPTS}" == "" ]; then
        JVM_PERFORMANCE_OPTS="-server -Xms512m -Xmx2048m -XX:PermSize=256m -XX:MaxPermSize=512m"
        # log "JVM_PERFORMANCE_OPTS not provided, default JVM_PERFORMANCE_OPTS=${JVM_PERFORMANCE_OPTS}."
    fi
    # JAVA_OPTS
    if [ "${JAVA_OPTS}" == "" ]; then
    # JAVA_OPTS SPRING_PROFILE
        if [ "${SPRING_PROFILE}" == "" ]; then
            SPRING_PROFILE="dev"
            # log "SPRING_PROFILE not provided, default SPRING_PROFILE=${SPRING_PROFILE}"
        fi
        JAVA_OPTS="-Dspring.profiles.active=${SPRING_PROFILE}"
        # log "JAVA_OPTS not provided, default JAVA_OPTS=${JAVA_OPTS}"
    fi
    # DIST_JAR
    if [ "${DIST_JAR}" == "" ]; then
        DIST_JAR=/opt/app.jar
    fi
    # APP_ARGS
    if [ "${APP_ARGS}" == "" ]; then
        APP_ARGS=""
        # log "APP_ARGS not provided, default APP_ARGS=${APP_ARGS}"
    fi

    export DIST_JAR_ARGS=${DIST_JAR_ARGS:-${JVM_ARGS_OPTS} ${JVM_PERFORMANCE_OPTS} ${JAVA_OPTS} -jar ${DIST_JAR} ${APP_ARGS}}
    log "args: ${DIST_JAR_ARGS}"

    export FAIL_RUN_DIST_JAR=0

    if [ "${DIST_JAR}" == "" ] || [ ! -f ${DIST_JAR} ]; then
        log "The File ${DIST_JAR} not found!"
        export FAIL_RUN_DIST_JAR=1
    fi

    if [ ${FAIL_RUN_DIST_JAR} != 1 ]; then
        log "exec java ${DIST_JAR_ARGS}"

    fi

}


function configureTomcat() {
    # patch CATALINA_APPBASE
    if [ ! "${CATALINA_APPBASE}" == "" ]; then
       sed -i '8d'  ${CATALINA_HOME}/bin/catalina.sh
    fi

}


function configureSupervisor() {

    mkdir -p /etc/supervisord.d/ \
    &&  { \
            echo '[unix_http_server]'; \
            echo 'file=/var/run/supervisor.sock'; \
            echo 'chmod=0777'; \
            echo 'username=admin'; \
            echo 'password=admin123'; \
            echo ''; \
            echo '[supervisord]'; \
            echo 'logfile=/tmp/ps.log'; \
            echo 'logfile_maxbytes=50MB'; \
            echo 'logfile_backups=10'; \
            echo 'loglevel=info'; \
            echo 'pidfile=/var/run/supervisord.pid'; \
            echo 'nodaemon=false'; \
            echo 'silent=true'; \
            echo 'minfds=1024'; \
            echo 'minprocs=200'; \
            echo 'user='`id -u`; \
            echo ''; \
            echo '[rpcinterface:supervisor]'; \
            echo 'supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface'; \
            echo ''; \
            echo '[supervisorctl]'; \
            echo 'serverurl=unix:///var/run/supervisor.sock'; \
            echo 'username=admin'; \
            echo 'password=admin123'; \
            echo ''; \
            echo '[include]'; \
            echo 'files = /etc/supervisord.d/*.ini'; \
            echo ''; \
        } | tee /etc/supervisord.conf >/dev/null 2>&1 \

    #---------------------------------------------------------------------------------------------------------

    # 取消控制台输出
    # CONFGURE_NGINX_FILE=/usr/local/openresty/nginx/conf
    # CONFGURE_NGINX_FILE=/opt/nginx/conf
    mkdir -p /var/run/openresty
    chmod 777 /var/run/openresty 
    ln -sf /dev/stdout /tmp/nginx_access.log
    ln -sf /dev/stderr /tmp/nginx_error.log

    NGX_CONFIGURE_PATH=${NGX_CONFIGURE_PATH:-/usr/local/openresty/nginx/conf}
    # supervisor openresty 定义文件
    { \
        echo '[program: openresty]'; \
        echo "command=/usr/local/openresty/bin/openresty -c $NGX_CONFIGURE_PATH/nginx.conf -g 'daemon off;' "; \
        echo 'autorestart=true'; \
        echo 'autostart=true'; \
        echo 'killasgroup=true'; \
        echo 'stopasgroup=true'; \
        echo 'startretries=5'; \
        echo 'numprocs=1'; \
        echo 'startsecs=0'; \
        echo 'process_name=%(program_name)s_%(process_num)02d'; \
        echo 'stdout_logfile=/tmp/nginx_access.log'; \
        echo 'stderr_logfile=/tmp/nginx_error.log'; \
        echo 'redirect_stderr=true'; \
        if [ -L /tmp/nginx_access.log ] ; then
            echo 'stdout_logfile_maxbytes=0'; \
        fi
        if [ -L /tmp/nginx_error.log ] ; then
            echo 'stderr_logfile_maxbytes=0'; \
        fi
        echo ''; \
    } | tee /etc/supervisord.d/openresty.ini.bak >/dev/null 2>&1 \


    #---------------------------------------------------------------------------------------------------------
    
    ln -sf /dev/stdout /tmp/tomcat_stdout.log
    ln -sf /dev/stderr /tmp/tomcat_stderr.log

    # supervisor tomcat 定义文件
    { \
        echo '[program: tomcat]'; \
        echo "command=/opt/tomcat/bin/catalina.sh " ${CATALINA_SH_ARGS:-run}; \
        echo 'autorestart=true'; \
        echo 'autostart=true'; \
        echo 'killasgroup=true'; \
        echo 'stopasgroup=true'; \
        echo 'startretries=5'; \
        echo 'numprocs=1'; \
        echo 'startsecs=0'; \
        echo 'process_name=%(program_name)s_%(process_num)02d'; \
        echo 'stdout_logfile=/tmp/tomcat_stdout.log'; \
        echo 'stderr_logfile=/tmp/tomcat_stderr.log'; \
        echo 'redirect_stderr=true'; \
        if [ -L /tmp/tomcat_stdout.log ] ; then
            echo 'stdout_logfile_maxbytes=0'; \
        fi
        if [ -L /tmp/tomcat_stderr.log ] ; then
            echo 'stderr_logfile_maxbytes=0'; \
        fi
        echo ''; \
    } | tee /etc/supervisord.d/tomcat.ini.bak >/dev/null 2>&1 \


    #---------------------------------------------------------------------------------------------------------

    ln -sf /dev/stdout /tmp/app_stdout.log
    ln -sf /dev/stderr /tmp/app_stderr.log

    # supervisor app 定义文件
    { \
        echo '[program: app]'; \
        echo "command=/opt/jdk/bin/java " ${DIST_JAR_ARGS:-}; \
        echo 'autorestart=true'; \
        echo 'autostart=true'; \
        echo 'killasgroup=true'; \
        echo 'stopasgroup=true'; \
        echo 'startretries=5'; \
        echo 'numprocs=1'; \
        echo 'startsecs=0'; \
        echo 'process_name=%(program_name)s_%(process_num)02d'; \
        echo 'stdout_logfile=/tmp/app_stdout.log'; \
        echo 'stderr_logfile=/tmp/app_stderr.log'; \
        echo 'redirect_stderr=true'; \
        if [ -L /tmp/app_stdout.log ] ; then
            echo 'stdout_logfile_maxbytes=0'; \
        fi
        if [ -L /tmp/app_stderr.log ] ; then
            echo 'stderr_logfile_maxbytes=0'; \
        fi
        echo ''; \
    } | tee /etc/supervisord.d/app.ini.bak >/dev/null 2>&1 \


}

function runSupervisor() {
    log "================================================================================"
    log "runSupervisor"
    # 
    configureOpenresty
    #
    configureApp
    #
    configureTomcat
    #
    configureSupervisor
    #
    cp /etc/supervisord.d/openresty.ini.bak /etc/supervisord.d/openresty.ini
    #
    if [ ${FAIL_RUN_DIST_JAR} != 1 ]; then
        cp /etc/supervisord.d/app.ini.bak /etc/supervisord.d/app.ini
    fi
    #
    if [ ${FAIL_RUN_DIST_JAR} == 1 ]; then
        cp /etc/supervisord.d/tomcat.ini.bak /etc/supervisord.d/tomcat.ini
    fi
    #
    /usr/bin/supervisord -c /etc/supervisord.conf -n
}



function runOpenresty() {
    log "================================================================================"
    log "runOpenresty"
    configureOpenresty
    configureSupervisor
    
    # 
    # /usr/local/openresty/bin/openresty -c /opt/nginx/conf/nginx.conf -g 'daemon off;'

    #
    cp /etc/supervisord.d/openresty.ini.bak /etc/supervisord.d/openresty.ini
    #
    /usr/bin/supervisord -c /etc/supervisord.conf -n

}

function runTomcat() {
    log "================================================================================"
    log "runTomcat"

    configureTomcat
    configureSupervisor

    #
    # /opt/tomcat/bin/catalina.sh ${CATALINA_SH_ARGS:-run}

    #
    cp /etc/supervisord.d/tomcat.ini.bak /etc/supervisord.d/tomcat.ini
    #
    /usr/bin/supervisord -c /etc/supervisord.conf -n

}

function runApp() {
    log "================================================================================"
    log "runApp"

    configureApp
    configureSupervisor

    if [ ${FAIL_RUN_DIST_JAR} != 1 ]; then
        #
        # exec java ${DIST_JAR_ARGS}

        #
        cp /etc/supervisord.d/app.ini.bak /etc/supervisord.d/app.ini
        #
        /usr/bin/supervisord -c /etc/supervisord.conf -n
    fi

}

function runShell() {
    log "================================================================================"
    $@

}

function main() {
    # SWITCH_RUN 取值 auto dist_jar tomcat none
    # 未发现DIST_JAR变量的jar文件，则直接运行tomcat 0 不运行
    SWITCH_RUN=${SWITCH_RUN:-"bash"}
    log "================================================================================"
    log "SWITCH_RUN=$SWITCH_RUN"

    if [ "${SWITCH_RUN}" == "bash" ] || [ "${SWITCH_RUN}" == "bash" ] ; then
        runShell $@
    fi

    if [ "${SWITCH_RUN}" == "INIT" ] || [ "${SWITCH_RUN}" == "init" ] ; then
        initScripts
        runShell $@
    fi

    if [ "${SWITCH_RUN}" == "SUPERVISOR" ] || [ "${SWITCH_RUN}" == "Supervisor" ] || [ "${SWITCH_RUN}" == "supervisor" ] || [ "${SWITCH_RUN}" == "ps" ]; then
        initScripts
        runSupervisor
    fi

    if [ "${SWITCH_RUN}" == "OPENRESTY" ] || [ "${SWITCH_RUN}" == "Openresty" ] || [ "${SWITCH_RUN}" == "openresty" ] || [ "${SWITCH_RUN}" == "nginx" ]; then
        initScripts
        runOpenresty
    fi

    if [ "${SWITCH_RUN}" == "DIST_JAR" ] || [ "${SWITCH_RUN}" == "dist_jar" ] || [ "${SWITCH_RUN}" == "app" ]; then
        initScripts
        runApp
    fi

    if [ "${SWITCH_RUN}" == "TOMCAT" ] || [ "${SWITCH_RUN}" == "tomcat" ] ; then
        initScripts
        runTomcat
    fi

    log "================================================================================"
    
}

main "$@"