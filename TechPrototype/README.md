# 安康助手后端

Spring Boot 后端骨架，服务于 Flutter 前端的登录、健康数据、提醒、SOS、我的页面和健康建议接口。

## 技术栈

- Java 17
- Spring Boot 3.x
- Spring Web
- Spring Validation
- MySQL Driver
- MyBatis-Plus
- Lombok
- Knife4j / OpenAPI
- Flyway

## 启动 MySQL

在项目根目录执行：

```bash
docker compose up -d
```

进入数据库：

```bash
docker exec -it ankang-mysql mysql -uankang -pankang123
```

数据库连接信息：

- Host: `localhost`
- Port: `3306`
- Database: `ankang_assistant`
- Username: `ankang`
- Password: `ankang123`
- Root password: `123456`

## 启动后端

```bash
cd backend
mvn spring-boot:run
```

后端默认端口：`8080`

## 测试接口

```text
http://localhost:8080/api/test/ping
```

期望返回：

```json
{
  "code": 200,
  "message": "success",
  "data": "backend is running"
}
```

## 通过 Nginx 访问

项目根目录的 Docker Compose 已包含本地 Nginx 反向代理。保持后端运行在
宿主机 `8080` 端口后，可启动 Nginx：

```bash
docker compose up -d nginx
```

默认代理入口：

```text
http://localhost:8088/api/test/ping
```

Android 模拟器通过 Nginx 联调时，将 API 地址设置为：

```text
http://10.0.2.2:8088/api
```

详细说明见 `deploy/nginx/README.md`。

## 接口文档

- Knife4j: `http://localhost:8080/doc.html`
- Swagger UI: `http://localhost:8080/swagger-ui/index.html`
- OpenAPI JSON: `http://localhost:8080/v3/api-docs`

## 模块说明

- `auth`: 登录、注册、短期 JWT 与可轮换 refresh token 会话。
- `user`: 用户资料、健康档案。
- `health`: 健康记录、首页摘要、趋势分析。
- `reminder`: 健康提醒。
- `emergency`: 紧急联系人、SOS 事件、附近医院。
- `advice`: 今日健康建议。
- `report`: 周健康报告，兼容前端 `ReportService`。
- `agent`: Health Action Agent，包含会话持久化、长期记忆、用户健康上下文、Mock Web Search、SSE 流式问答、健康安全边界、结构化 action 和确认执行工具。
- `medicalsummary`: 实时汇总健康档案、近期指标、风险事件、用药提醒和数据来源，供 App 在就诊现场只读展示。
- `eventmesh`: 健康记录提交后的异步事件编排，包含医学规则、个体基线、
  趋势检测、多指标联合异常、SSE 风险推送和 SOS 预案。
- `family`: 家庭协同照护，使用独立账号、绑定码和 `care_relation` 授权关系，让家属只读查看被照护者数据并基于 patient 上下文咨询 Agent。
- `common`: 统一响应、错误码、全局异常处理。
- `config`: CORS、MyBatis-Plus、Knife4j。

个体化风险算法的公式、阈值、冷启动和测试方法见
[`docs/PERSONALIZED_HEALTH_RISK_ALGORITHM.md`](docs/PERSONALIZED_HEALTH_RISK_ALGORITHM.md)。
App 内结构化就医摘要的统计口径、接口和安全边界见
[`docs/MEDICAL_SUMMARY.md`](docs/MEDICAL_SUMMARY.md)。

## Agent 模块

默认本地环境使用 mock 模式，无需配置真实大模型或搜索 API key 即可启动。

```yaml
agent:
  provider: mock
  api-key: ${AGENT_API_KEY:}
  base-url: ${AGENT_BASE_URL:https://models.sjtu.edu.cn/api/v1}
  model-name: ${AGENT_MODEL_NAME:deepseek-chat}
  web-search:
    enabled: true
    provider: ${WEB_SEARCH_PROVIDER:mock}
    api-key: ${WEB_SEARCH_API_KEY:}
    base-url: ${WEB_SEARCH_BASE_URL:}
    max-results: 5
    timeout-seconds: 8
  gms:
    enabled: ${GMS_ENABLED:false}
    write-enabled: ${GMS_WRITE_ENABLED:true}
    base-url: ${GMS_BASE_URL:http://127.0.0.1:8091}
    timeout-millis: ${GMS_TIMEOUT_MILLIS:800}
    read-limit: ${GMS_READ_LIMIT:5}
```

Agent 当前仍是单 Agent 架构。结构化健康数据继续来自 MySQL；可选 GMS 只作为 Agent 语义记忆 sidecar 使用，默认关闭。开启 `GMS_ENABLED=true` 后，病人自己的聊天会异步写入 GMS，问答前会从 GMS 拉取相关 Agent 记忆注入 Prompt；家属视角只读取被照护者的 GMS 记忆，不把家属提问写成病人记忆。`rag_document` 和 `rag_chunk_metadata` 仅保留为后续知识库扩展占位。普通问答保持原 `/api/agent/chat`，新增 action 能力通过兼容字段 `pendingAction` 暴露给前端。

Qdrant RAG 记忆库的部署与 1000 用户写入检索验证见：`docs/RAG_QDRANT_SCALE_TEST.md`。当前验证覆盖向量库 collection、payload 索引、公共/私有数据 filter 隔离和批量写入检索；后端 RAG API 接入仍需单独实现。

主要接口：

- `POST /api/agent/chat`: 普通健康问答。
- `POST /api/agent/actions/confirm`: 用户确认或取消待执行 Action。
- `POST /api/agent/chat/stream`: SSE 流式问答，当前用完整回答分片模拟 token 流。
- `GET /api/agent/sessions`: 查询当前用户会话。
- `GET /api/agent/sessions/{id}/messages`: 查询会话消息。
- `DELETE /api/agent/sessions/{id}`: 软删除会话。

Web Search 工具：

- 触发词包括“最新、最近、指南、政策、查询、搜索、文献、药品、副作用、禁忌、医保、医院”等。
- 未配置真实搜索 API key 时自动使用 `MockWebSearchClient`。
- 搜索失败不会中断聊天，Agent 会退回普通上下文回答。
- 搜索结果会注入 Prompt，并以 `citations` 返回给前端。

Health Action Agent 工具：

- `RECORD_HEALTH_DATA`: 用户确认后录入血压、血糖、心率、体重，并同步返回风险评估。
- `CREATE_HEALTH_PLAN`: 用户确认后把明确时间的计划创建为提醒；模糊计划只返回建议。
- `EVALUATE_HEALTH_RISK`: 只读风险评估，可直接执行。
- `PREPARE_SOS_PLAN`: 生成 SOS 预案，不发起 SOS、不拨号、不发短信。
- `SEARCH_NEARBY_HOSPITALS`: 根据经纬度查询附近医院；无地图 key 时 mock fallback。
- `NOTIFY_FAMILY_PREVIEW`: 只准备通知家属的消息预览，不发送。

Action 存储在 `agent_action` 表，默认 10 分钟过期。确认接口会校验当前用户、actor/target、状态、过期时间和 payload，已执行 action 重复确认不会重复写入。

健康安全边界：

- Agent 是健康管理助手，不是医生。
- 不给出确诊结论，不替代医生诊疗。
- 药物剂量、停药、换药必须提示遵医嘱。
- 用户提到胸痛、呼吸困难、昏迷、意识不清、中风、抽搐、严重出血、严重低血糖、剧烈头痛等高风险症状时，回答必须提示“建议立即联系医生或拨打当地急救电话”。
- LLM 只能输出结构化 action；数据库写入、SOS、通知都必须经过后端校验和用户确认。

## 家庭协同照护模式

家庭照护不采用账号共享。病人和家属各自使用独立账号，病人在“家庭照护”入口生成绑定码，家属登录自己的账号后输入绑定码建立 `care_relation`。

后端 family 接口全部位于 `/api/family/**`。读取病人健康摘要、健康记录、趋势、提醒和 SOS 记录前，都会通过 `FamilyPermissionService` 校验当前登录用户是否是该 patient 的 active caregiver。数据来自 patient 原始表，不复制、不 mock。

病人端现有接口保持完整能力：录入健康数据、管理提醒、SOS、Agent、档案和个人信息都不变。家属端只读，不提供新增、修改、删除病人健康数据、提醒、档案、紧急联系人或替病人发起 SOS 的接口。

家属 Agent 使用 `actorUserId = caregiverUserId`、`targetUserId = patientUserId`、`actorRole = CAREGIVER`。会话归属家属，健康上下文读取被照护者，家属提问不会写入 patient 的 `agent_memory`。

家属版 Action 权限更窄：允许风险评估、SOS 预案和通知预览，不允许直接录入病人健康数据或创建/修改病人提醒。

## 常见问题

1. MySQL 启动失败或 3306 被占用  
   检查本机是否已有 MySQL 占用端口，必要时调整根目录 `docker-compose.yml` 的端口映射。

2. 后端启动时数据库连接失败  
   先确认 `docker compose up -d` 已成功启动，并等待 MySQL 初始化完成。

3. Flutter Web 访问跨域失败  
   当前 CORS 已允许 `http://localhost:8081`、`http://127.0.0.1:8081`、`http://localhost:3000`、`http://localhost:5173`。

4. Flutter Android 模拟器访问地址  
   前端当前 dev baseUrl 为 `http://10.0.2.2:8080/api`，适合 Android 模拟器访问宿主机后端。
