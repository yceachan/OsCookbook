---
title: Steam++ Hosts 模式下的证书信任与 Steam 卡登录处置流程
tags: [steam++, watt-toolkit, mitm, nss, ca-trust, fedora]
note_types: [Jotting]
created: 2026-09-14
updated: 2026-09-14/
---

# Steam++ Hosts 模式下的证书信任与 Steam 卡登录处置流程

> [!note]
> **Ref:** 证书 `~/.local/share/Steam++/Plugins/Accelerator/SteamTools.Certificate.cer`
> · Steam++ 错误日志 `~/.cache/Steam++/Logs/nlog-all-<date>.log`
> · 加速器 stdout `journalctl --user -u 'app-Watt\x20Toolkit@<hash>.service'`
> · Steam 侧 `~/.local/share/Steam/logs/{connection_log,cef_log,console-linux}.txt`

## Abstract

Hosts 模式把目标域解析到 `127.0.0.1`，由本地 443 反代做 TLS 终止，所以每个客户端都必须信任 Steam++ 自签的 `SteamTools Certificate`。信任落点分三类：用户级 NSS 库（浏览器导入用）、系统 CA 包（libcurl/OpenSSL 系）、Chromium 内置验证器（Steam 内嵌浏览器 CEF，自成一库）。这次 Steam 卡登录就卡在第二类——`api.steampowered.com` 被劫持而 Steam 自带 libcurl 校验失败，登录第一步 `GetCMListForConnect` 永远拿不到 CM 列表。

## 链路

```
客户端 → 域名解析 127.0.0.1（/etc/hosts）→ Steam++ 反代 0.0.0.0:443
       → 叶证书 CN=<目标域>，issuer=CN=SteamTools Certificate（CA:TRUE, pathlen 1）
       → 客户端用各自信任库校验该 CA
```

## 1. 定位

```bash
# 谁被劫持了
grep -c '^127\.0\.0\.1' /etc/hosts          # 17 条 = 加速生效中

# 反代是否在跑、给的是什么证书
ss -ltnpe | grep -E ':(80|443) '
openssl s_client -connect 127.0.0.1:443 -servername api.steampowered.com -showcerts </dev/null

# 原生栈能不能过（关键判据：不带 --cacert 应成功）
curl -s -o /dev/null -w '%{http_code} tls=%{ssl_verify_result}\n' \
  --resolve api.steampowered.com:443:127.0.0.1 \
  'https://api.steampowered.com/ISteamDirectory/GetCMListForConnect/v1/?cellid=48&qoslevel=3'

# Steam 卡在哪一步
tail -4 ~/.local/share/Steam/logs/connection_log.txt   # 停在 GetCMListForConnect
grep -a cert_verify_proc_builtin ~/.local/share/Steam/logs/cef_log.txt  # No matching issuer found
```

三条日志各指向一层：`connection_log.txt` 卡在 `ISteamDirectory/GetCMListForConnect` = 原生栈；`cef_log.txt` 的 `CertVerifyProcBuiltin … No matching issuer found` = 内嵌浏览器（CEF）；`console-linux.txt` 的 `Peer certificate cannot be authenticated with given CA certificates` = 同属原生栈（breakpad 上传）。

## 2. 修复

把 CA 装进系统信任库（Fedora / RHEL 路径），然后只重启 Steam，**不重启 Steam++**：反代只是签发叶证书的一方，不读系统信任库，证书本身也没变，无需重载。

```bash
sudo cp ~/.local/share/Steam++/Plugins/Accelerator/SteamTools.Certificate.cer \
        /etc/pki/ca-trust/source/anchors/steamtools.crt
sudo update-ca-trust
```

`update-ca-trust` 会重建 `/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem`，而 Steam 二进制引用的 `/etc/ssl/certs/ca-certificates.crt` 正是指向它的符号链接。Steam 必须完全退出重启——卡住的请求与进程内的 CA 上下文不会自己恢复。

## 3. 验证

```bash
# 系统 CA 路径（不带 --cacert）应给出正常状态码，且 OpenSSL 校验通过
for h in api.steampowered.com login.steampowered.com store.steampowered.com; do
  curl -s -o /dev/null -w "$h -> %{http_code} tls=%{ssl_verify_result}\n" \
    --resolve $h:443:127.0.0.1 https://$h/
done
# 期望：api 404 / login 302 / store 200，tls=0（0=校验通过）
```

重启 Steam 后看 `connection_log.txt` 是否越过 `GetCMListForConnect`、`cef_log.txt` 是否还有新的 `No matching issuer found`。

## 4. 备忘

- 用户级 NSS 导入（`~/.pki/nssdb`，`certutil -A -n <名> -t 'CT,C,C'`）对 Steam 原生栈无效，对 CEF 也无效——CEF 用的是 Chromium 内置验证器，日志里是 `cert_verify_proc_builtin`，不读 NSS。要影响它只能靠系统信任库或换模式。
- 不想要证书这一环，就改用系统代理模式：HTTPS 走 CONNECT 隧道、不做 TLS 终止，客户端无需信任任何自签 CA。Hosts 模式的代价就是必须逐客户端铺 CA。
- Steam++ 每次启停代理都会检查并在缺失时往用户级 NSS 库补装自己的证书，日志表现为 `证书 'SteamTools' 存在。`；启停瞬间会连带刷出一批 `StartOrStopProxyService TaskCanceledException`（DoH 候选被取消），属噪声。
- 陷阱：以普通用户执行 `certutil -L -d sql:/etc/pki/nssdb` 会**静默回落到用户库**，看起来像“系统库里也有该证书”。查系统库请用 `sudo`，或直接读 `/etc/pki/nssdb/cert9.db`：

```bash
python3 -c "import sqlite3;print(sqlite3.connect('file:/etc/pki/nssdb/cert9.db?mode=ro',uri=True).execute('select count(*) from nssPublic').fetchone())"
```
