```sh
# 开启代理（适配clash/verge等默认7897端口，可自行修改）
function proxy() {
    export http_proxy="http://127.0.0.1:7897"
    export https_proxy="http://127.0.0.1:7897"
    export HTTP_PROXY="http://127.0.0.1:7897"
    export HTTPS_PROXY="http://127.0.0.1:7897"
    echo -e "\033[32mProxy enabled: http://127.0.0.1:7897\033[0m"
}

# 关闭代理
function unproxy() {
    unset http_proxy https_proxy
    unset HTTP_PROXY HTTPS_PROXY
    echo -e "\033[33mProxy disabled\033[0m"
}

# 检查当前代理状态
function check-proxy() {
    if [ -n "$http_proxy" ] || [ -n "$https_proxy" ]; then
        echo -e "\033[36mCurrent proxy settings:\033[0m"
        echo "HTTP Proxy: $http_proxy"
        echo "HTTPS Proxy: $https_proxy"
    else
        echo -e "\033[36mNo proxy is currently set.\033[0m"
    fi
}
```
