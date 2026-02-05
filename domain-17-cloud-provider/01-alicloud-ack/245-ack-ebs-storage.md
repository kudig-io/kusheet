# ACK 关联产品 - EBS 云盘存储 (Elastic Block Storage)

> **适用版本**: ACK v1.25 - v1.32 | **最后更新**: 2026-01

---

## 目录

- [ESSD 性能等级详解](#essd-性能等级详解)
- [CSI 驱动优化配置](#csi-驱动优化配置)
- [存储安全: 加密与快照](#存储安全-加密与快照)
- [动态扩容与迁移路径](#动态扩容与迁移路径)
- [成本模型与选型建议](#成本模型与选型建议)

---

## ESSD 性能等级详解

EBS (ESSD) 是 ACK 生产环境最主流的块存储，支持 **PL (Performance Level)** 动态调整。

| 等级 | 单盘最大 IOPS | 最大吞吐 (MB/s) | 延迟 (ms) | 典型应用 |
|:---|:---|:---|:---|:---|
| **ESSD Entry** | 2,500 | 180 | 1-10 | 入门级应用、小流量 Web |
| **ESSD PL0** | 10,000 | 180 | 1 | 开发、测试环境 |
| **ESSD PL1** | 50,000 | 350 | <1 | **默认生产推荐** (MySQL, Redis) |
| **ESSD PL2** | 100,000 | 750 | <1 | 高并发核心数据库 (Oracle, PG) |
| **ESSD PL3** | 1,000,000 | 4,000 | <1 | 极高性能 OLTP、高性能计算 |

---

## CSI 驱动优化配置

### 生产级 StorageClass 示例

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alibabacloud-disk-essd
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  # 云盘类型: cloud_essd
  type: cloud_essd
  # 性能等级: PL1
  performanceLevel: PL1
  # 延迟绑定，优化跨 AZ 调度
  volumeBindingMode: WaitForFirstConsumer
  # 扩容开关
  allowVolumeExpansion: "true"
reclaimPolicy: Retain
```

### 挂载参数优化

建议在 `mountOptions` 中添加针对 Linux 内核的优化：

- `noatime`: 减少写入操作。
- `nodiratime`: 禁用目录时间更新。
- `logbufs=8`: 提高 XFS/ext4 的日志缓冲。

---

## 存储安全: 加密与快照

### 云盘加密

ACK 支持通过 KMS 服务实现云盘的静态加密。

```yaml
parameters:
  encrypted: "true"
  # kmsKeyId (可选): 不填则使用默认 KMS 密钥
  kmsKeyId: "ad4b-..." 
```

### 快照策略 (Backup Strategy)

| 方案 | 特点 | 场景 |
|:---|:---|:---|
| **自动快照策略** | 在阿里云控制台全局配置 | 基础容灾 (全量) |
| **CSI Snapshot** | 使用 K8s `VolumeSnapshot` 对象 | 业务触发、状态管理 |
| **自定义备份** | 结合 Velero + 阿里云 OSS | 跨集群应用级备份 |

---

## 动态扩容与迁移路径

### 扩容限制

- **只能增不能减**: 云盘支持在线/离线扩容，但不支持缩容。
- **文件系统刷新**: XFS 需要在线扩容后执行 `xfs_growfs`；ext4 执行 `resize2fs`。ACK CSI 驱动会自动处理这些原子操作。

### 迁移建议

1. **同可用区迁移**: 直接卸载挂载即可。
2. **跨可用区迁移**: 必须通过快照创建新云盘，或使用跨 AZ 的存储服务 (如跨 AZ 分发的 NAS)。

---

## 成本模型与选型建议

### 成本估算参考 (100GB/月)

- **高效云盘**: 约 35 元
- **ESSD PL0**: 约 105 元
- **ESSD PL1**: 约 150 元

### 选型建议

1. **读写极高场景**: 优先 PL2/PL3，且单盘空间不宜过小 (IOPS 与空间正相关)。
2. **高可用需求**: 云盘是单可用区资源，若应用需要高可用，应在多个 AZ 部署副本 Pod，并各挂一个独立的 PV。

---

## 相关文档

- [76-storageclass-dynamic-provisioning.md](./76-storageclass-dynamic-provisioning.md) - 存储类动态供给
- [166-csi-container-storage-deep-dive.md](./166-csi-container-storage-deep-dive.md) - CSI 规范深度解析
- [156-alibaba-cloud-integration.md](./156-alibaba-cloud-integration.md) - 阿里云集成总表
