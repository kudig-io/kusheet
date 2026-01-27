# Linux 安全加固

> **适用版本**: Linux Kernel 5.x/6.x | **最后更新**: 2026-01

---

## 目录

- [用户与权限管理](#用户与权限管理)
- [SSH 安全配置](#ssh-安全配置)
- [PAM 认证配置](#pam-认证配置)
- [SELinux/AppArmor](#selinuxapparmor)
- [审计与日志](#审计与日志)
- [安全基线检查](#安全基线检查)

---

## 用户与权限管理

### 用户管理

```bash
# 添加用户
useradd -m -s /bin/bash username

# 设置密码
passwd username

# 添加到 sudo 组
usermod -aG sudo username    # Debian/Ubuntu
usermod -aG wheel username   # RHEL/CentOS

# 禁用账户
usermod -L username

# 删除账户
userdel -r username
```

### 密码策略

```bash
# /etc/login.defs
PASS_MAX_DAYS   90      # 最大有效期
PASS_MIN_DAYS   7       # 最小修改间隔
PASS_MIN_LEN    12      # 最小长度
PASS_WARN_AGE   14      # 过期警告天数

# 密码复杂度 (PAM)
# /etc/security/pwquality.conf
minlen = 12
dcredit = -1    # 至少1个数字
ucredit = -1    # 至少1个大写
lcredit = -1    # 至少1个小写
ocredit = -1    # 至少1个特殊字符
```

### sudo 配置

```bash
# /etc/sudoers.d/admin
admin ALL=(ALL) NOPASSWD: ALL

# 限制命令
webadmin ALL=(ALL) /bin/systemctl restart nginx
```

### 锁定账户

```bash
# 锁定
passwd -l username
chage -E 0 username

# 解锁
passwd -u username
chage -E -1 username

# 禁用 shell
usermod -s /sbin/nologin username
```

---

## SSH 安全配置

### /etc/ssh/sshd_config

```bash
# 禁用 root 登录
PermitRootLogin no

# 禁用密码认证
PasswordAuthentication no
PubkeyAuthentication yes

# 限制用户
AllowUsers admin deploy
AllowGroups sshusers

# 修改端口
Port 22022

# 连接限制
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 30

# 禁用空密码
PermitEmptyPasswords no

# 协议版本
Protocol 2

# 超时配置
ClientAliveInterval 300
ClientAliveCountMax 2
```

### SSH 密钥管理

```bash
# 生成密钥
ssh-keygen -t ed25519 -C "user@host"

# 复制公钥
ssh-copy-id user@host

# 权限设置
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### 重启生效

```bash
systemctl restart sshd
```

---

## PAM 认证配置

### 登录失败锁定

```bash
# /etc/pam.d/system-auth (RHEL)
# /etc/pam.d/common-auth (Ubuntu)

auth required pam_faillock.so preauth silent deny=5 unlock_time=900
auth required pam_faillock.so authfail deny=5 unlock_time=900

# 查看锁定状态
faillock --user username

# 解锁
faillock --user username --reset
```

### 密码历史

```bash
# /etc/pam.d/system-auth
password required pam_pwhistory.so remember=12 use_authtok
```

---

## SELinux/AppArmor

### SELinux

```bash
# 查看状态
getenforce
sestatus

# 临时切换
setenforce 0    # Permissive
setenforce 1    # Enforcing

# 永久配置 /etc/selinux/config
SELINUX=enforcing

# 上下文管理
ls -Z
restorecon -Rv /path
semanage fcontext -a -t httpd_sys_content_t "/web(/.*)?"

# 布尔值
getsebool -a | grep httpd
setsebool -P httpd_can_network_connect on
```

### AppArmor

```bash
# 查看状态
aa-status

# 配置文件目录
/etc/apparmor.d/

# 管理命令
aa-enforce /etc/apparmor.d/usr.sbin.nginx
aa-complain /etc/apparmor.d/usr.sbin.nginx
```

---

## 审计与日志

### auditd

```bash
# 安装
yum install audit    # RHEL
apt install auditd   # Ubuntu

# 启动
systemctl enable auditd
systemctl start auditd

# 规则示例 /etc/audit/rules.d/audit.rules
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/sudoers -p wa -k sudoers_changes
-a always,exit -F arch=b64 -S execve -k exec

# 查看日志
ausearch -k passwd_changes
aureport
```

### 日志管理

```bash
# 重要日志
/var/log/auth.log        # 认证日志 (Ubuntu)
/var/log/secure          # 认证日志 (RHEL)
/var/log/messages        # 系统日志
/var/log/audit/audit.log # 审计日志

# journald
journalctl -u sshd -f
journalctl --since "1 hour ago"
```

### 日志轮转

```bash
# /etc/logrotate.d/custom
/var/log/myapp/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    create 0640 root root
}
```

---

## 安全基线检查

### 检查清单

| 项目 | 检查命令 | 期望结果 |
|:---|:---|:---|
| UID 0 账户 | `awk -F: '$3==0' /etc/passwd` | 仅 root |
| 空密码账户 | `awk -F: '$2==""' /etc/shadow` | 无结果 |
| SSH root | `grep PermitRootLogin /etc/ssh/sshd_config` | no |
| 密码认证 | `grep PasswordAuthentication /etc/ssh/sshd_config` | no |
| SELinux | `getenforce` | Enforcing |

### 自动化工具

```bash
# Lynis 安全审计
lynis audit system

# OpenSCAP
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_cis \
    --results results.xml /usr/share/xml/scap/ssg/content/ssg-rhel8-ds.xml
```

### 快速加固脚本

```bash
#!/bin/bash
# 基础加固

# 禁用不需要的服务
systemctl disable --now rpcbind

# 限制 cron 访问
echo "root" > /etc/cron.allow

# 设置 umask
echo "umask 027" >> /etc/profile

# 内核安全参数
cat >> /etc/sysctl.d/99-security.conf << EOF
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.log_martians = 1
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
EOF

sysctl --system
```

---

## 相关文档

- [210-linux-system-architecture](./210-linux-system-architecture.md) - 系统架构
- [217-linux-container-fundamentals](./217-linux-container-fundamentals.md) - 容器基础
- [206-docker-security-best-practices](./206-docker-security-best-practices.md) - Docker 安全
