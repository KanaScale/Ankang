# 云端压力测试

## 前置条件

1. 云端使用专用测试账号。
2. 使用 `seed-health-records-10k.sql` 在测试数据库为该账号准备至少 10,000 条记录。
3. Agent 使用 Mock 配置，不测试短信、电话、SOS 和外部付费模型。
4. 压测机公网 IP 已加入 WAF/限流测试白名单。

## 批量注册 100 个测试账号

在 PowerShell 中执行：

```powershell
cd D:\SEpro\SE25Project-11

.\scripts\performance\register-perf-users.ps1 `
  -BaseUrl "https://api.ankangxai.cn" `
  -Count 100 `
  -Prefix "perf_user_" `
  -Password "<专用测试密码>"
```

将创建 `perf_user_001` 至 `perf_user_100`。结果保存在：

- `scripts/performance/perf-register-results.csv`
- `scripts/performance/perf-usernames.json`

结果文件不会保存密码。不要提交生成的账号文件。

账号创建完成后，在云端测试数据库执行：

```text
scripts/performance/seed-perf-users-10k.sql
```

该脚本为 100 个账号分别创建 100 条健康记录，共 10,000 条。再次执行时会跳过已经存在的 `perf-batch-*` 记录。

## 执行

```powershell
$env:BASE_URL = "https://api.ankangxai.cn"
$env:PERF_PASSWORD = "<100个账号共用的专用测试密码>"
$env:TARGET_VUS = "100"
$env:HOLD_DURATION = "5m"

New-Item -ItemType Directory -Force .\reports

k6 run `
  --summary-export=.\reports\stress-summary.json `
  .\scripts\performance\k6-cloud-stress.js 2>&1 |
  Tee-Object .\reports\stress-console.txt
```

## 通过标准

- 数据量不少于 10,000 条。
- 并发用户数达到 100，并保持 5 分钟。
- `http_req_failed < 1%`。
- `http_req_duration p(95) < 3000ms`。
- `http_req_duration p(99) < 3000ms`。
- `checks > 99%`。

测试期间同步记录后端、Nginx、MySQL、Redis 的 CPU、内存、连接数和错误日志。
