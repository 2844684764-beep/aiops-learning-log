# D6 · Linux 排查 cheat sheet

> 自己写的，不是抄的。四类问题：**CPU 高 / 端口不通 / 慢但 CPU 不高 / 服务起不来**。
> 原稿写在 `handbook/W1-第1周.md` 的 D6 节，这里整理成可长期用的版本。

---

## {CPU 高}

**看**：`top` 里的 `%Cpu(s)`（重点看 `us` / `sy` / `wa`）和 `load average`

**异常**：

- `us` 高 = 用户态占用高，通常是应用在疯狂计算（死循环等）
- `sy` 高 = 系统态占用高，频繁的系统调用（大量网络包处理、IO 操作）
- `wa` 高 = 等着 IO 的 CPU 占比高，说明 CPU 其实在等磁盘或网络
- `load average` 远大于 CPU 核心数 → 系统严重拥堵

**下一步**：

```bash
ps aux --sort=-%cpu | head -10     # 找进程
top -H -p <pid>                    # 找线程
```

---

## {服务连不上 / 端口不通}

**看**：

```bash
ss -tlnp | grep <端口>
# 或
netstat -tulnp | grep <端口>
```

**异常**：

- 没输出 = 服务没启动成功，或者没监听在这个端口
- 有输出但连不上 = 监听在 `127.0.0.1` 而不是 `0.0.0.0`，或者被防火墙拦了

**下一步**：

```bash
systemctl status firewalld        # 查防火墙
iptables -L -n                    # 云服务器还要查安全组
systemctl status <服务名>          # 查服务状态
```

---

## {系统慢但 CPU 不高}

**看**：`iostat -x 1` 的 `%util` 和 `await`，或者 `top` 里的 `wa`

**异常**：

- `%util` 接近 100% = 磁盘读写被打满
- `await` 数值很高 = 单次 IO 响应极慢

**下一步**：

```bash
df -h                # 是不是满了
iotop -o             # 需要 root，直接看谁在疯狂读写
pidstat -d 1         # iotop 没装时的替代
```

---

## {服务起不来}

**看**：`systemctl status <服务名>`（active 状态 + 最后几行报错）

**异常**：

- 状态是 `failed`
- 日志提示 `address already in use`（端口被占）或 `permission denied`（权限不够）

**下一步**：

```bash
journalctl -u <服务名> -n 50 --no-pager -xe   # 看第一行报错，通常是根因
lsof -i:<端口>                                 # 谁占了端口
```

再看配置文件有没有语法错误（`nginx.conf`、`docker-compose.yml`）。

---

## 在本项目里怎么用

这套 cheat sheet 直接对应你搭的这套系统：

| 场景 | 命令 |
|---|---|
| 8000 端口是不是在听 | `ss -tlnp \| grep 8000` |
| 占端口的进程谁管的 | `ps -o pid,ppid,args -p <PID>`，**父进程是 1 = systemd** |
| 业务服务日志 | `journalctl -u aiops-app -f` |
| 容器日志 | `docker logs grafana --tail 50` |
| 容器状态 | `docker ps -a` |
| 磁盘是不是满了 | `df -h /`（根分区 36G） |

**一个已经踩过的坑**：8000 端口「杀不死」——`Restart=always` 会让 systemd 3 秒内拉起。
看到「端口被占 + 父进程是 1」，答案永远是 `systemctl stop/restart`，不是 `kill`。
