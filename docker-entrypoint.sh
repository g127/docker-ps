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

    mkdir -p /var/run/openresty
    chmod 777 /var/run/openresty 

}

function configureApp() {
    # ================================================================================
    # 执行前的准备脚本，部分环境变量
    # ================================================================================
    # DIST_APP
    DIST_APP="${DIST_JAR:-/opt/app.jar}"
    DIST_APP_ARGS="${APP_ARGS:""}"

    if [ ! -f ${DIST_APP} ]; then
        export FAIL_RUN_DIST_APP="The DIST_APP File ${DIST_APP} not found!"
        # log ${FAIL_RUN_DIST_APP}
    else
        # Java 变量后缀 如果是java的jar文件
        if [ ${DIST_APP##*.} == "jar" ]; then

            mkdir -p /tmp/web/tmp.java
            # JVM_ARGS_OPTS 默认值
            DEFAULT_JVM_ARGS_OPTS="-Djava.io.tmpdir=/tmp/web/tmp.java -Djava.security.egd=file:/dev/./urandom -Duser.timezone=GMT+08"
            # JVM_PERFORMANCE_OPTS 默认值
            DEFAULT_JVM_PERFORMANCE_OPTS="-server -Xms512m -Xmx2048m -XX:PermSize=256m -XX:MaxPermSize=512m"
            # SPRING_PROFILE 默认值
            DEFAULT_SPRING_PROFILE="dev"
            # JAVA_OPTS 默认值
            DEFAULT_JAVA_OPTS="-Dspring.profiles.active=${SPRING_PROFILE:-${DEFAULT_SPRING_PROFILE}}"

            # 外部传入
            JVM_ARGS_OPTS="${JVM_ARGS_OPTS:-${DEFAULT_JVM_ARGS_OPTS}}"
            JVM_PERFORMANCE_OPTS="${JVM_PERFORMANCE_OPTS:-${DEFAULT_JVM_PERFORMANCE_OPTS}}"
            JAVA_OPTS="${JAVA_OPTS:-${DEFAULT_JAVA_OPTS}}"
            #
            JAVA_HOME="${JAVA_HOME:-/opt/jdk}"
            JAVA_EXEC="${JAVA_EXEC:-${JAVA_HOME}/bin/java}"
            #
            JAVA_ENV_ARGS="${JAVA_ENV_ARGS:-${JVM_ARGS_OPTS} ${JVM_PERFORMANCE_OPTS} ${JAVA_OPTS}}"

            # DIST_APP_ARGS
            DIST_APP_ARGS="${DIST_APP_ARGS:-${JAVA_ENV_ARGS}}"

            # 传出变量
            export DIST_APP_COMMAND=${DIST_APP_COMMAND:-${JAVA_EXEC} -jar ${DIST_APP} ${DIST_APP_ARGS} }
            log "cmd: ${DIST_APP_COMMAND}"

        # Python 变量后缀 如果是Python的py文件
        elif [ ${DIST_APP##*.} == "py" ]; then
            log "DIST_APP: ${DIST_APP} not support!" 

        # 其他文件
        else
            # 传出变量
            export DIST_APP_COMMAND=${DIST_APP_COMMAND:-${DIST_APP} ${DIST_APP_ARGS} }
            log "cmd: ${DIST_APP_COMMAND}"
        fi 
    fi



}


function configureTomcat() {
    # patch CATALINA_APPBASE
    if [ ! "${CATALINA_APPBASE}" == "" ]; then
       sed -i '8d'  ${CATALINA_HOME}/bin/catalina.sh
    fi

}


function configureSupervisor() {
    # /etc/
    export SUPERVISORD_CONF_PATH=${SUPERVISORD_CONF_PATH:-/etc}
    # /etc/supervisord.d
    export SUPERVISORD_CONF_D_PATH=${SUPERVISORD_CONF_D_PATH:-"${SUPERVISORD_CONF_PATH}/supervisord.d"}
    # log "SUPERVISORD_CONF_PATH: ${SUPERVISORD_CONF_PATH}"
    # log "SUPERVISORD_CONF_D_PATH: ${SUPERVISORD_CONF_D_PATH}"
    mkdir -p ${SUPERVISORD_CONF_D_PATH} \
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
            echo "files = "${SUPERVISORD_CONF_D_PATH}"/*.ini"; \
            echo ''; \
        } | tee ${SUPERVISORD_CONF_PATH}/supervisord.conf.bak >/dev/null 2>&1 \

    #---------------------------------------------------------------------------------------------------------

    # 取消控制台输出
    ln -sf /dev/stdout /tmp/nginx_access.log
    ln -sf /dev/stderr /tmp/nginx_error.log

    NGX_CONFIGURE_PATH=${NGX_CONFIGURE_PATH:-/usr/local/openresty/nginx/conf}

    COMMAND="/usr/local/openresty/bin/openresty -c $NGX_CONFIGURE_PATH/nginx.conf -g 'daemon off;' "

    # supervisor openresty 定义文件
    { \
        echo '[program: openresty]'; \
        echo "command="${COMMAND}; \
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
    } | tee ${SUPERVISORD_CONF_D_PATH}/openresty.ini.bak >/dev/null 2>&1 \


    #---------------------------------------------------------------------------------------------------------
    
    ln -sf /dev/stdout /tmp/tomcat_stdout.log
    ln -sf /dev/stderr /tmp/tomcat_stderr.log
    
    COMMAND="/opt/tomcat/bin/catalina.sh ${CATALINA_SH_ARGS:-run}"

    # supervisor tomcat 定义文件
    { \
        echo '[program: tomcat]'; \
        echo "command="${COMMAND}; \
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
    } | tee ${SUPERVISORD_CONF_D_PATH}/tomcat.ini.bak >/dev/null 2>&1 \


    #---------------------------------------------------------------------------------------------------------

    ln -sf /dev/stdout /tmp/app_stdout.log
    ln -sf /dev/stderr /tmp/app_stderr.log

    COMMAND=${DIST_APP_COMMAND:-}

    # supervisor app 定义文件
    { \
        echo '[program: app]'; \
        echo "command="${COMMAND:-}; \
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
    } | tee ${SUPERVISORD_CONF_D_PATH}/app.ini.bak >/dev/null 2>&1 \

    #---------------------------------------------------------------------------------------------------------


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
    cp ${SUPERVISORD_CONF_PATH}/supervisord.conf.bak ${SUPERVISORD_CONF_PATH}/supervisord.conf
    #
    cp ${SUPERVISORD_CONF_D_PATH}/openresty.ini.bak  ${SUPERVISORD_CONF_D_PATH}/openresty.ini
    #
    if [ "${FAIL_RUN_DIST_APP}" == "" ]; then
        cp ${SUPERVISORD_CONF_D_PATH}/app.ini.bak ${SUPERVISORD_CONF_D_PATH}/app.ini
    else
        cp ${SUPERVISORD_CONF_D_PATH}/tomcat.ini.bak ${SUPERVISORD_CONF_D_PATH}/tomcat.ini
        log "runApp Failure, then runTomcat starts automatically. Cause By: ${FAIL_RUN_DIST_APP}"
    fi
    #
    /usr/bin/supervisord -c ${SUPERVISORD_CONF_PATH}/supervisord.conf -n
}



function runOpenresty() {
    log "================================================================================"
    log "runOpenresty"
    configureOpenresty
    configureSupervisor
    
    # 
    # /usr/local/openresty/bin/openresty -c /opt/nginx/conf/nginx.conf -g 'daemon off;'
    #
    cp ${SUPERVISORD_CONF_PATH}/supervisord.conf.bak ${SUPERVISORD_CONF_PATH}/supervisord.conf
    #
    cp ${SUPERVISORD_CONF_D_PATH}/openresty.ini.bak ${SUPERVISORD_CONF_D_PATH}/openresty.ini
    #
    /usr/bin/supervisord -c ${SUPERVISORD_CONF_PATH}/supervisord.conf -n

}

function runTomcat() {
    log "================================================================================"
    log "runTomcat"

    configureTomcat
    configureSupervisor

    #
    # /opt/tomcat/bin/catalina.sh ${CATALINA_SH_ARGS:-run}
    #
    cp ${SUPERVISORD_CONF_PATH}/supervisord.conf.bak ${SUPERVISORD_CONF_PATH}/supervisord.conf
    #
    cp ${SUPERVISORD_CONF_D_PATH}/tomcat.ini.bak ${SUPERVISORD_CONF_D_PATH}/tomcat.ini
    #
    /usr/bin/supervisord -c ${SUPERVISORD_CONF_PATH}/supervisord.conf -n

}

function runApp() {
    log "================================================================================"
    log "runApp"

    configureApp
    configureSupervisor

    if [ "${FAIL_RUN_DIST_APP}" == "" ]; then
        #
        # exec java ${DIST_JAR_ARGS}
        #
        cp ${SUPERVISORD_CONF_PATH}/supervisord.conf.bak ${SUPERVISORD_CONF_PATH}/supervisord.conf
        #
        cp ${SUPERVISORD_CONF_D_PATH}/app.ini.bak ${SUPERVISORD_CONF_D_PATH}/app.ini
        #
        /usr/bin/supervisord -c ${SUPERVISORD_CONF_PATH}/supervisord.conf -n
    else 
        log "runApp Failure! Cause By: ${FAIL_RUN_DIST_APP}"
    fi

}

function runShell() {
    log "================================================================================"
    $@

}

function main() {
    # SWITCH_RUN 取值 bash init ps nginx app tomcat
    # 未发现DIST_JAR变量的jar文件，则直接运行tomcat 0 不运行
    SWITCH_RUN=${SWITCH_RUN:-"bash"}
    log "================================================================================"
    log "SWITCH_RUN=$SWITCH_RUN"

    if [ "${SWITCH_RUN}" == "BASH" ] || [ "${SWITCH_RUN}" == "bash" ] ; then
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