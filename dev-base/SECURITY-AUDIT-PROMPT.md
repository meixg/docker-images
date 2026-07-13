# dev-base 宿主机独立安全审计提示词

将下面的提示词交给宿主机上的任意 Agent。该审计不得依赖代码仓库、
README、Compose 文件或安全配置脚本，只能根据宿主机和运行中容器的实际
状态得出结论。

---

请对当前 Linux 宿主机上的 dev-base Docker 安全隔离进行一次独立、只读审计。

本次审计不得读取或依赖任何代码仓库、README、Compose 文件、安全脚本或脚本
输出。必须直接检查：

- Docker daemon 的实时配置
- Linux 用户命名空间
- UFW/iptables 的实时规则
- Docker 网络与容器的实际运行状态
- 宿主机实际监听端口
- 实际网络连通性

已知预期架构：

- 容器名称：`dev-base`
- Docker 网络名称：`dev-base-restricted`
- 宿主机 Docker bridge：`devbase0`
- SSH 宿主机端口：`2222`
- SSH 容器端口：`22`
- SSH 仅绑定当前宿主机的 Tailscale IPv4
- Docker 使用 `userns-remap=default`
- 容器不得访问宿主机、家庭 LAN 或其他 Tailnet 节点
- 容器允许访问公网
- 容器不得挂载任何 volume、宿主机目录或 `docker.sock`
- 容器不得使用 privileged、host network 或 host PID
- 容器应禁用 IPv6 并移除 `NET_RAW` capability

## 安全约束

1. 只允许执行读取、状态检查和有限连通性测试。
2. 可以执行只读 `sudo` 命令。
3. 不得修改任何文件或防火墙规则。
4. 不得运行任何 apply、remove、install、restart、enable、disable、reset、flush
   或规则清零操作。
5. 不得启动、停止或重建容器。
6. 不得安装软件。
7. 不得扫描家庭网络。
8. 不得在报告中输出真实 Tailscale IP、MagicDNS hostname、SSH key、家庭 LAN
   地址、公网 IP、个人用户名或完整环境变量；统一写成 `[REDACTED]`。
9. 发现问题只报告，不自动修复。
10. 不得把配置文件中的声明当作生效证据，必须与实时状态交叉验证。

## 一、Docker daemon 与 userns-remap

直接检查：

- `/etc/docker/daemon.json` 是否是普通文件而非 symlink。
- JSON 是否有效。
- `userns-remap` 是否设置为 `default`。
- `docker info` 的 `SecurityOptions` 是否包含 `name=userns`。
- Docker 是否意外运行在 rootless 模式。
- `dockremap` 用户和组是否存在。
- `/etc/subuid` 和 `/etc/subgid` 是否包含 `dockremap`。
- `dockremap` 首个 subordinate range 是否至少包含 65536 个 ID。
- 所有 subordinate UID/GID ranges 是否存在重叠。
- 配置文件与 Docker 实时状态是否一致。

不得打印 `daemon.json` 的完整内容，只报告 `userns-remap` 字段状态和是否存在
其他配置字段。

## 二、实际 UID 映射

如果 `dev-base` 正在运行：

1. 读取容器 PID。
2. 检查 `/proc/<pid>/uid_map` 和 `gid_map`。
3. 确认容器 UID/GID 0 映射到非零宿主机 ID。
4. 确认映射起点与 `dockremap` 的 subordinate range 一致。
5. 检查宿主机看到的容器主进程 UID，确认不是宿主机 UID 0。

如果容器未运行，标记为 `UNVERIFIED`，不要启动容器。

## 三、Docker 网络

直接使用 `docker network inspect`、`ip link` 和运行时网络状态确认：

- `dev-base-restricted` 存在。
- 网络驱动为 bridge。
- 对应宿主机接口确实是 `devbase0`。
- `devbase0` 处于 UP。
- IPv6 未启用。
- `dev-base` 只连接到预期网络。
- 容器没有全局或链路本地 IPv6 地址。
- `NetworkMode` 不是 host。
- 容器没有连接其他可能绕过防火墙的网络。

不要打印完整 Docker subnet、gateway 或容器 IP，只报告是否符合预期。

## 四、容器权限与挂载

通过 `docker inspect` 的实际 `HostConfig` 和 `Mounts` 检查：

- `Privileged=false`。
- `PidMode` 为空且不是 host。
- `IpcMode` 不是 host。
- `NetworkMode` 不是 host。
- `Mounts` 为空。
- `Binds` 为空。
- 没有 named volume。
- 没有 `/var/run/docker.sock`。
- 没有宿主机根目录、home、SSH、AWS、配置目录或设备映射。
- `CapDrop` 包含 `NET_RAW`。
- `CapAdd` 不包含 `NET_ADMIN`、`SYS_ADMIN`、`SYS_PTRACE`、`SYS_MODULE` 等
  高风险 capability。
- 没有 Device 映射。
- 没有设置 `userns=host` 来绕过 daemon 的 `userns-remap`。

不要输出环境变量值。仅报告是否发现疑似 token、密码、私钥或个人标识信息。

## 五、SSH 端口绑定

获取当前宿主机 Tailscale IPv4，但不得打印。

通过以下独立证据交叉验证：

- `docker inspect` 中的 `HostIp`
- `docker port dev-base 22`
- `ss -lntp` 或等价工具的实际监听地址
- 当前 Tailscale 接口地址

必须确认：

- `2222` 只绑定当前 Tailscale IPv4。
- 没有绑定 `0.0.0.0:2222`。
- 没有绑定 `[::]:2222`。
- 没有绑定 `localhost:2222`。
- 没有绑定家庭 LAN 地址的 `2222`。
- 没有其他进程额外代理或转发该端口。

## 六、SSH 服务加固

在不修改容器的前提下执行容器内 `sshd -T`，确认：

- `passwordauthentication no`
- `kbdinteractiveauthentication no`
- `permitrootlogin no`
- `allowusers` 仅包含 `dev`
- `maxauthtries 3`
- `x11forwarding no`
- `allowtcpforwarding no`

同时确认：

- 容器内没有为 root 配置可用 SSH 登录。
- `authorized_keys` 权限合理。
- 不打印 `authorized_keys` 内容或指纹。

## 七、UFW 与 Docker 防火墙集成

直接检查 UFW、`iptables-save`、`iptables -S` 或等价的实时规则，不依赖任何
辅助脚本。

确认：

- UFW 为 active。
- Docker 使用与 UFW 规则兼容的 iptables backend。
- `DOCKER-USER` 链存在。
- `DOCKER-USER` 实际跳转到 `ufw-user-forward` 或等效的 UFW forward 链。
- 该跳转当前存在于内核实时规则中，而不只是写在配置文件中。
- Docker daemon 重启后没有造成规则文件与实时链不一致。
- 规则只针对 `devbase0` 流量，不影响其他正常 Docker 网络。
- INPUT 路径阻止从 `devbase0` 发起到宿主机的连接。
- FORWARD 路径阻止从 `devbase0` 发起到以下目标的新连接：

  - `0.0.0.0/8`
  - `10.0.0.0/8`
  - `100.64.0.0/10`
  - `127.0.0.0/8`
  - `169.254.0.0/16`
  - `172.16.0.0/12`
  - `192.168.0.0/16`
  - `224.0.0.0/4`
  - `240.0.0.0/4`

必须分析实际规则顺序：

- 是否有更早的 ACCEPT 或 RETURN 导致 `devbase0` 绕过拒绝规则。
- established/related 是否只允许已有连接的返回流量。
- 是否存在允许容器主动访问整个 Tailnet 或家庭网络的宽泛规则。
- Docker 自动生成规则是否绕过了 UFW 拒绝规则。
- IPv6 是否可能绕过 IPv4 防火墙。

## 八、网络连通性测试

仅在 `dev-base` 已经运行时测试，不要启动它。

公网测试：

- 容器 DNS 应正常。
- 容器应能与 `https://api.openai.com` 建立 TLS/HTTP 连接。
- HTTP 401、403 或其他鉴权响应可以视为网络连通成功。
- 不得提交凭据。

私网阻断测试：

- 自动发现但不要打印宿主机 bridge gateway。
- 自动发现但不要打印宿主机 LAN 地址。
- 自动发现但不要打印家庭默认网关。
- 获取但不要打印宿主机 Tailscale IP。
- 从容器分别尝试连接上述目标，单次超时不超过 3 秒。
- 所有由容器主动发起的连接都应该失败。
- 不要尝试其他 LAN 地址，不要执行端口扫描。

注意：目标端口本身关闭也会导致连接失败，因此私网测试结果必须与实时
INPUT/FORWARD 规则共同判断，不能单独作为 PASS 依据。

## 九、Tailscale 入站 SSH

宿主机本地无法完整证明 Tailscale 入站访问正常。

必须分析防火墙转发路径，重点确认：

- 从 `tailscale0` 到 `devbase0:22` 的新连接不会被 `ufw-docker` 的默认私网
  目标拒绝规则意外丢弃。
- 返回流量能通过 established/related 规则。
- 仅绑定 Tailscale IP 不等于防火墙一定允许该连接。

将实际远程连接验证列为 `REMOTE TEST REQUIRED`：

从另一台已授权 Tailnet 设备执行：

```bash
ssh -p 2222 dev@<desktop-magicdns-hostname>
```

预期：

- 已授权设备能够连接。
- 未授权身份或设备不能连接。
- 家庭 LAN 直接访问 `desktop:2222` 失败。
- 公网无法访问该端口。

如果没有第二台设备，不得将此项标记为 PASS。

## 十、隐私与凭据

只检查正在运行的容器和 Docker 配置，不搜索个人 home 目录。

确认：

- 容器没有挂载宿主机数据。
- 容器环境没有 API token、密码、私钥或云凭据。
- `SSH_PUB_KEY` 即使属于公钥，也不得输出。
- Docker daemon 配置中如果存在代理认证或其他敏感字段，不得输出其值。
- 报告中不得出现任何真实 IP、hostname、用户名、email 或 key。

## 输出要求

最终报告使用表格，每项只能为：

- `PASS`：通过独立的实时证据验证。
- `FAIL`：实际状态不符合预期。
- `UNVERIFIED`：当前状态不足以验证。
- `REMOTE TEST REQUIRED`：必须从另一台 Tailnet 设备验证。

至少包含：

1. Docker daemon userns-remap
2. dockremap subordinate ranges
3. 实际 UID/GID 映射
4. Docker 网络与 devbase0
5. IPv6 状态
6. capabilities 与 privileged 状态
7. volume、bind mount 和 docker.sock
8. Tailscale 端口绑定
9. SSH hardening
10. UFW/DOCKER-USER 实时集成
11. 家庭网络出站阻断
12. 公网访问
13. Tailscale 入站 SSH
14. 运行时凭据与隐私

总体结论只能为：

- `SAFE TO USE`
- `NOT SAFE TO USE`
- `CONDITIONALLY SAFE`

判定规则：

- 任一关键隔离项为 FAIL，不得给出 `SAFE TO USE`。
- Tailscale 入站尚未远程验证时，最多只能给出 `CONDITIONALLY SAFE`。
- 防火墙规则仅存在于文件、但不在内核实时规则中时，判定 FAIL。
- 只验证配置、没有验证实际行为时，不得判定 PASS。
- 最后列出最小修复建议，但不要执行任何修复。
