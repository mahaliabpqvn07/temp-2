#!/bin/sh

NZ_BASE_PATH="$HOME/nezha"
NZ_AGENT_PATH="${NZ_BASE_PATH}/agent"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

err() {
    printf "${red}%s${plain}\n" "$*" >&2
}

success() {
    printf "${green}%s${plain}\n" "$*"
}

info() {
    printf "${yellow}%s${plain}\n" "$*"
}

sudo() {
    myEUID=$(id -ru)
    if [ "$myEUID" -ne 0 ]; then
        if command -v > /dev/null 2>&1; then
            command "$@"
        else
            err "ERROR: is not installed on the system, the action cannot be proceeded."
            exit 1
        fi
    else
        "$@"
    fi
}

deps_check() {
    local deps="curl unzip grep"
    local _err=0
    local missing=""

    for dep in $deps; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            _err=1
            missing="${missing} $dep"
        fi
    done

    if [ "$_err" -ne 0 ]; then
        err "Missing dependencies:$missing. Please install them and try again."
        exit 1
    fi
}

geo_check() {
    api_list="https://blog.cloudflare.com/cdn-cgi/trace https://developers.cloudflare.com/cdn-cgi/trace"
    ua="Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/81.0"
    set -- "$api_list"
    for url in $api_list; do
        text="$(curl -A "$ua" -m 10 -s "$url")"
        endpoint="$(echo "$text" | sed -n 's/.*h=\([^ ]*\).*/\1/p')"
        if echo "$text" | grep -qw 'CN'; then
            isCN=true
            break
        elif echo "$url" | grep -q "$endpoint"; then
            break
        fi
    done
}

env_check() {
    mach=$(uname -m)
    case "$mach" in
        amd64|x86_64)
            os_arch="amd64"
            ;;
        i386|i686)
            os_arch="386"
            ;;
        aarch64|arm64)
            os_arch="arm64"
            ;;
        *arm*)
            os_arch="arm"
            ;;
        s390x)
            os_arch="s390x"
            ;;
        riscv64)
            os_arch="riscv64"
            ;;
        mips)
            os_arch="mips"
            ;;
        mipsel|mipsle)
            os_arch="mipsle"
            ;;
        *)
            err "Unknown architecture: $mach"
            exit 1
            ;;
    esac

    system=$(uname)
    case "$system" in
        *Linux*)
            os="linux"
            ;;
        *Darwin*)
            os="darwin"
            ;;
        *FreeBSD*)
            os="freebsd"
            ;;
        *)
            err "Unknown architecture: $system"
            exit 1
            ;;
    esac
}

init() {
    deps_check
    env_check

    ## China_IP
    if [ -z "$CN" ]; then
        geo_check
        if [ -n "$isCN" ]; then
            CN=true
        fi
    fi

    if [ -z "$CN" ]; then
        GITHUB_URL="github.com"
    else
        GITHUB_URL="gitee.com"
    fi
}

install() {
    echo "Installing..."

    if [ -z "$CN" ]; then
        NZ_AGENT_URL="https://${GITHUB_URL}/nezhahq/agent/releases/latest/download/nezha-agent_${os}_${os_arch}.zip"
    else
        _version=$(curl -m 10 -sL "https://gitee.com/api/v5/repos/naibahq/agent/releases/latest" | awk -F '"' '{for(i=1;i<=NF;i++){if($i=="tag_name"){print $(i+2)}}}')
        NZ_AGENT_URL="https://${GITHUB_URL}/naibahq/agent/releases/download/${_version}/nezha-agent_${os}_${os_arch}.zip"
    fi

    if command -v wget >/dev/null 2>&1; then
        _cmd="wget --timeout=60 -O /tmp/nezha-agent_${os}_${os_arch}.zip \"$NZ_AGENT_URL\" >/dev/null 2>&1"
    elif command -v curl >/dev/null 2>&1; then
        _cmd="curl --max-time 60 -fsSL \"$NZ_AGENT_URL\" -o /tmp/nezha-agent_${os}_${os_arch}.zip >/dev/null 2>&1"
    fi

    if ! eval "$_cmd"; then
        err "Download nezha-agent release failed, check your network connectivity"
        exit 1
    fi

    mkdir -p "$NZ_AGENT_PATH"

    unzip -qo /tmp/nezha-agent_${os}_${os_arch}.zip -d "$NZ_AGENT_PATH" &&
        rm -rf /tmp/nezha-agent_${os}_${os_arch}.zip

    path="$NZ_AGENT_PATH/config.yml"
    if [ -f "$path" ]; then
        random=$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 5)
        path=$(printf "%s" "$NZ_AGENT_PATH/config-$random.yml")
    fi

    if [ -z "$NZ_SERVER" ]; then
        err "NZ_SERVER should not be empty"
        exit 1
    fi

    if [ -z "$NZ_CLIENT_SECRET" ]; then
        err "NZ_CLIENT_SECRET should not be empty"
        exit 1
    fi

    # 创建配置文件
    cat > "$path" << EOF
debug: false
server: $NZ_SERVER
client_secret: $NZ_CLIENT_SECRET
tls: ${NZ_TLS:-true}
skip_connection_count: ${NZ_SKIP_CONNECTION_COUNT:-false}
skip_procs_count: ${NZ_SKIP_PROCS_COUNT:-false}
disable_auto_update: ${NZ_DISABLE_AUTO_UPDATE:-false}
disable_force_update: ${NZ_DISABLE_FORCE_UPDATE:-false}
disable_command_execute: ${NZ_DISABLE_COMMAND_EXECUTE:-false}
EOF

    # 创建启动脚本
    cat > "${NZ_BASE_PATH}/start.sh" << EOF
#!/bin/bash
cd "${NZ_AGENT_PATH}"
echo "启动 nezha-agent..."
nohup ./nezha-agent -c "$path" > ../nezha-agent.log 2>&1 &
echo "nezha-agent 已在后台启动"
echo "日志文件: ${NZ_BASE_PATH}/nezha-agent.log"
echo "查看日志: tail -f ${NZ_BASE_PATH}/nezha-agent.log"
echo "停止服务: pkill -f nezha-agent"
EOF
    chmod +x "${NZ_BASE_PATH}/start.sh"

    # 创建停止脚本
    cat > "${NZ_BASE_PATH}/stop.sh" << EOF
#!/bin/bash
echo "停止 nezha-agent..."
pkill -f nezha-agent
echo "nezha-agent 已停止"
EOF
    chmod +x "${NZ_BASE_PATH}/stop.sh"

    # 直接启动
    echo "正在启动 nezha-agent..."
    cd "${NZ_AGENT_PATH}"
    nohup ./nezha-agent -c "$path" > ../nezha-agent.log 2>&1 &
    sleep 2
    if pgrep -f nezha-agent > /dev/null; then
        success "nezha-agent successfully installed and started"
        info "日志文件: ${NZ_BASE_PATH}/nezha-agent.log"
        info "启动服务: ${NZ_BASE_PATH}/start.sh"
        info "停止服务: ${NZ_BASE_PATH}/stop.sh"
        info "查看日志: tail -f ${NZ_BASE_PATH}/nezha-agent.log"
    else
        err "nezha-agent启动失败，请查看日志: ${NZ_BASE_PATH}/nezha-agent.log"
        exit 1
    fi
}

uninstall() {
    echo "停止nezha-agent进程..."
    pkill -f nezha-agent
    echo "删除文件..."
    rm -rf "$NZ_BASE_PATH"
    info "Uninstallation completed."
}

if [ "$1" = "uninstall" ]; then
    uninstall
    exit
fi

init
install
