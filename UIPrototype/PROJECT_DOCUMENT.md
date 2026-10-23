# 安康助手：面向老人与慢病患者的健康安全智能助手项目文档

## 摘要

本系统采用 Flutter + Spring Boot + MySQL 的前后端分离架构。Flutter App 负责用户界面展示和交互，Spring Boot 后端负责业务逻辑、权限认证和数据处理，MySQL 负责持久化存储用户健康数据。系统面向老人与慢病患者，提供健康档案管理、健康数据记录、健康提醒、紧急救援、健康趋势分析和个性化健康建议等功能，并可扩展 RAG 智能问答能力。

---

## 1. 项目概述

### 1.1 项目名称

**安康助手：面向老人与慢病患者的健康安全智能助手**

### 1.2 项目背景

随着人口老龄化趋势加剧，以及高血压、糖尿病、心血管疾病等慢性病患者数量持续增加，家庭场景下的日常健康管理、异常监测和紧急救援需求愈发突出。许多老年用户存在以下问题：

- 健康数据记录不连续，缺乏长期趋势观察手段
- 服药、体检、测量血压血糖等事项容易遗忘
- 紧急情况下无法快速联系家属或寻求帮助
- 缺少简单、直观、持续可用的健康建议服务

基于上述问题，本项目设计并实现一个面向老人和慢病患者的移动健康管理系统。系统以 Android 平台上的 Flutter App 作为用户入口，以 Spring Boot 作为后端服务核心，以 MySQL 作为业务数据存储中心，形成稳定、可扩展的前后端分离解决方案。

### 1.3 目标用户

- 老年人用户
- 高血压患者
- 糖尿病患者
- 心率异常或需要长期监测健康指标的用户
- 需要协助照护家中老人的家庭成员

### 1.4 项目目标

本项目的主要目标如下：

- 提供简单易用的健康档案与健康数据记录功能
- 提供服药提醒、测量提醒、体检复诊提醒等功能
- 提供一键 SOS 呼救与紧急联系人联动能力
- 对用户健康数据进行趋势分析与异常统计
- 根据规则生成个性化健康建议
- 在基础功能稳定的前提下，为后续 RAG 智能问答扩展预留架构空间

---

## 2. 需求分析

### 2.1 功能性需求

#### 2.1.1 用户认证与账户管理

- 用户可以注册账号并登录系统
- 用户登录后获取 JWT 令牌
- 用户可以查看个人信息
- 用户可以修改个人基本资料

#### 2.1.2 健康档案管理

- 用户可以维护身高、体重、年龄、性别、慢病类型、过敏史等信息
- 用户可以更新健康档案内容
- 系统可基于档案辅助生成健康建议

#### 2.1.3 健康数据记录管理

- 用户可以手动录入血压、心率、血糖、体重等数据
- 用户可以查看历史健康记录
- 用户可以按照时间范围和指标类型筛选数据
- 系统可以展示折线图、趋势图等数据可视化结果

#### 2.1.4 健康提醒管理

- 用户可以设置服药提醒
- 用户可以设置测血压提醒
- 用户可以设置测血糖提醒
- 用户可以设置体检、复诊提醒
- 支持每日、每周、单次提醒类型
- 系统可生成通知消息并在客户端展示

#### 2.1.5 紧急救援管理

- 用户可以维护紧急联系人列表
- App 提供一键 SOS 呼救按钮
- SOS 时上传当前定位信息
- 后端记录紧急事件
- 当检测到连续异常健康数据时，系统可自动生成预警事件

#### 2.1.6 健康数据分析

- 对血压、血糖、心率等数据进行趋势分析
- 统计某个时间周期内异常指标出现次数
- 生成周报或月报
- 提供图表化结果与文本总结

#### 2.1.7 个性化健康建议

- 基于预设规则生成建议
- 示例：连续多天血压偏高时，提示复测、规律服药、咨询医生
- 示例：空腹血糖连续异常时，提示饮食管理和复诊建议
- 明确提示健康建议仅作辅助，不替代专业医疗诊断

#### 2.1.8 智能问答模块，可选

- 基于健康知识库回答常见问题
- 使用 RAG 检索增强生成技术
- 保存问答历史记录
- 必须明确声明该模块为进阶扩展功能，不属于最小可运行版本必做内容

### 2.2 非功能性需求

- 界面清晰易读，适合老人使用
- Android 客户端兼容常见分辨率和屏幕尺寸
- 系统支持不少于 10k 条健康数据的管理与查询
- 在 100 并发场景下重点接口平均响应时间控制在 3 秒以内
- 用户健康数据必须具备鉴权保护
- 系统应具备良好的可维护性与可扩展性

### 2.3 进阶需求

- 引入 Python FastAPI 构建 AI 服务模块
- 使用 RAG 技术接入健康知识库
- 接入大模型 API 或本地模型实现智能问答
- 使用 FAISS 或 pgvector 进行向量检索
- 增加异常检测规则引擎，提高自动预警能力

---

## 3. 总体架构设计

### 3.1 系统总体架构

本系统采用典型的前后端分离架构。客户端、服务端、数据库各自承担独立职责，通过标准接口进行协作，降低耦合度并提高系统可维护性。

### 3.2 系统架构图

#### 3.2.1 基础版本架构图

```text
+---------------------+         HTTPS/JSON         +--------------------------+         JDBC/JPA         +------------------+
| Flutter Android App |  ----------------------->  | Spring Boot Backend API  |  ---------------------> | MySQL Database   |
|                     |  <-----------------------  |                          |  <--------------------- |                  |
| 页面展示与交互      |         RESTful API        | 业务逻辑/鉴权/数据处理   |       数据读写         | 持久化存储       |
+---------------------+                            +--------------------------+                         +------------------+
```

#### 3.2.2 含 AI 扩展的可选架构图

```text
+---------------------+         HTTPS/JSON         +--------------------------+         JDBC/JPA         +------------------+
| Flutter Android App |  ----------------------->  | Spring Boot Backend API  |  ---------------------> | MySQL Database   |
+---------------------+                            +--------------------------+                         +------------------+
                                                          |
                                                          | HTTP/JSON
                                                          v
                                                +--------------------------+
                                                | Python FastAPI AI Service|
                                                | RAG问答/知识检索/建议增强 |
                                                +--------------------------+
                                                          |
                                                          v
                                                +--------------------------+
                                                | Knowledge Base / Vector  |
                                                | FAISS / pgvector         |
                                                +--------------------------+
```

### 3.3 前后端分离说明

本项目必须明确采用前后端分离方式：

- Flutter App 负责界面展示、用户输入、页面交互、本地 token 管理、调用后端接口
- Flutter **不直接连接 MySQL**
- Flutter 通过 HTTP/HTTPS 请求调用 Spring Boot 后端 REST API
- Spring Boot 负责业务逻辑、权限校验、数据校验、异常处理、报表生成与建议计算
- Spring Boot 通过 Spring Data JPA 操作 MySQL
- MySQL 负责持久化存储用户信息、健康档案、健康记录、提醒、通知与紧急事件等数据

### 3.4 Flutter、Spring Boot、MySQL 的职责划分

| 组件 | 核心职责 | 不负责内容 |
|---|---|---|
| Flutter App | 页面展示、用户输入、趋势图展示、提醒展示、一键呼救入口、调用 REST API | 不直接访问数据库，不承担核心业务校验 |
| Spring Boot Backend | 登录注册、JWT 鉴权、业务逻辑处理、健康分析、提醒管理、紧急救援处理、数据权限控制 | 不直接负责终端 UI 展示 |
| MySQL | 业务数据持久化、索引支持、条件查询、报表数据基础支撑 | 不承担业务逻辑，不向客户端直接开放 |

### 3.5 可选 AI 服务扩展架构说明

AI 模块属于**进阶功能**，不是最小可运行版本必须完成的部分。其扩展方式如下：

- Spring Boot 保持主业务系统核心地位
- Python FastAPI 独立提供 AI 问答接口
- AI 服务负责知识检索、提示词构造、调用大模型、返回结果
- 知识库用于存放慢病管理、用药常识、日常保健等文档内容
- 为降低耦合，AI 能力通过独立 HTTP 接口接入，不影响基础业务模块运行

---

## 4. 技术栈选型

### 4.1 前端技术栈

- Flutter
- Dart
- Android 运行端
- HTTP 网络请求库，如 `dio` 或 `http`
- 本地安全存储，如 `flutter_secure_storage`
- 图表展示库，如 `fl_chart`

### 4.2 后端技术栈

- Java 17
- Spring Boot
- Spring Security
- JWT
- Spring Data JPA
- Hibernate Validator
- Lombok
- Maven

### 4.3 数据库技术栈

- MySQL 8.x

### 4.4 可选 AI 技术栈

- Python 3
- FastAPI
- 向量数据库或向量索引，如 FAISS / pgvector
- 大模型 API 或本地模型
- RAG 检索增强生成方案

### 4.5 技术选型理由

| 技术 | 选型理由 |
|---|---|
| Flutter | 一套代码可面向多平台扩展，UI 组件丰富，适合移动端快速开发，图表展示能力较强 |
| Dart | 与 Flutter 原生配套，开发效率高，语法清晰 |
| Spring Boot | Java 生态成熟，适合构建标准 RESTful API，易于分层管理和模块扩展 |
| Spring Security + JWT | 便于实现无状态认证，适合移动端接口鉴权 |
| Spring Data JPA | 降低数据库访问层开发成本，适合课程项目快速构建标准 CRUD 功能 |
| MySQL | 成熟稳定，支持事务、索引、分页和复杂查询，适合作为课程项目数据库 |
| FastAPI | 开发 AI 接口速度快，便于与 Python 生态和大模型能力集成 |
| FAISS / pgvector | 适合实现知识检索和 RAG 扩展能力 |

---

## 5. 功能模块设计

### 5.1 用户认证模块

主要功能：

- 注册
- 登录
- 获取当前用户信息
- token 校验与刷新策略预留

模块说明：

- 用户注册时，后端校验手机号或用户名唯一性
- 密码使用 BCrypt 加密存储
- 登录成功后返回 JWT
- 前端后续请求在请求头中携带 `Authorization: Bearer <token>`

### 5.2 健康档案模块

主要功能：

- 查看健康档案
- 编辑健康档案
- 维护基础信息和慢病信息

档案字段示例：

- 身高
- 体重
- 性别
- 出生日期
- 血型
- 慢病类型
- 过敏史
- 既往病史
- 紧急备注

### 5.3 健康数据记录模块

主要功能：

- 录入血压、心率、血糖、体重等记录
- 按日期、指标类型查询历史记录
- 展示趋势数据
- 统计异常次数

设计说明：

- 采用统一 `health_record` 表存储不同指标类型
- 通过 `type` 字段区分血压、血糖、心率等
- 支持记录测量时间、备注、来源等信息

### 5.4 健康提醒模块

主要功能：

- 新增提醒
- 修改提醒
- 启用或停用提醒
- 生成提醒消息
- 展示通知记录

提醒类型包括：

- 服药提醒
- 血压测量提醒
- 血糖测量提醒
- 复诊提醒
- 体检提醒

### 5.5 紧急救援模块

主要功能：

- 维护紧急联系人
- 一键 SOS 呼救
- 上报地理位置
- 记录紧急事件
- 异常指标自动预警

设计说明：

- 用户点击 SOS 后，前端提交位置、说明、时间
- 后端保存事件记录并返回受理状态
- 后续可扩展短信、推送、电话等联动方式

### 5.6 健康数据分析模块

主要功能：

- 单指标趋势分析
- 时间区间统计
- 异常次数统计
- 周报/月报生成

分析结果包括：

- 指标均值
- 最大值
- 最小值
- 异常次数
- 趋势判断
- 风险提示

### 5.7 健康建议模块

主要功能：

- 基于规则生成个性化建议
- 基于近一段时间的趋势与异常情况输出说明

规则示例：

- 连续 3 天收缩压高于 140 mmHg，提示减少高盐饮食并尽快复测
- 空腹血糖连续异常，提示关注饮食和复诊
- 一周记录次数过少，提示坚持规律记录

### 5.8 智能问答模块，可选

主要功能：

- 回答常见慢病管理问题
- 返回知识来源摘要
- 保存问答历史

重要说明：

- 该模块为进阶扩展功能
- 不作为最小可运行版本的必做内容
- 输出内容必须附带免责声明：**回答仅供健康管理参考，不能替代医生诊断和治疗建议**

---

## 6. 前端架构设计

### 6.1 Flutter 目录结构

```text
lib/
├── main.dart
├── app.dart
├── config/
│   ├── app_config.dart
│   └── api_config.dart
├── models/
│   ├── user_model.dart
│   ├── health_profile_model.dart
│   ├── health_record_model.dart
│   ├── reminder_model.dart
│   ├── notification_model.dart
│   ├── emergency_contact_model.dart
│   └── emergency_event_model.dart
├── services/
│   ├── api_client.dart
│   ├── auth_service.dart
│   ├── profile_service.dart
│   ├── record_service.dart
│   ├── reminder_service.dart
│   ├── emergency_service.dart
│   ├── report_service.dart
│   └── advice_service.dart
├── pages/
│   ├── auth/
│   │   ├── login_page.dart
│   │   └── register_page.dart
│   ├── home/
│   │   └── home_page.dart
│   ├── profile/
│   │   └── profile_page.dart
│   ├── records/
│   │   ├── record_list_page.dart
│   │   ├── record_form_page.dart
│   │   └── trend_page.dart
│   ├── reminders/
│   │   ├── reminder_list_page.dart
│   │   └── reminder_form_page.dart
│   ├── emergency/
│   │   ├── sos_page.dart
│   │   └── contact_page.dart
│   ├── reports/
│   │   └── weekly_report_page.dart
│   └── advice/
│       └── advice_page.dart
├── widgets/
│   ├── common_button.dart
│   ├── health_card.dart
│   ├── trend_chart.dart
│   └── empty_view.dart
└── utils/
    ├── token_storage.dart
    ├── date_util.dart
    ├── validator_util.dart
    └── constants.dart
```

### 6.2 页面划分

- 登录页：用户登录
- 注册页：新用户注册
- 首页：展示快捷入口、最近健康数据、提醒概览、SOS 入口
- 健康档案页：查看和编辑个人健康档案
- 健康记录页：查看与新增健康数据
- 趋势分析页：图表展示血压、血糖、心率等趋势
- 提醒管理页：新增、编辑、删除提醒
- 紧急联系人页：维护联系人列表
- SOS 呼救页：一键上报紧急事件
- 周报页：查看健康报告
- 建议页：查看系统生成的健康建议
- 智能问答页，可选：提交问题并查看回答历史

### 6.3 `models`、`services`、`pages`、`widgets`、`utils` 的职责

| 目录 | 职责 |
|---|---|
| models | 对应后端返回的数据结构，负责实体映射与 JSON 序列化 |
| services | 封装 API 请求逻辑，隔离页面与网络层 |
| pages | 承载完整页面与业务交互流程 |
| widgets | 可复用 UI 组件，如图表卡片、按钮、列表项 |
| utils | 工具函数、常量、校验逻辑、token 存储封装 |

### 6.4 Flutter 如何调用后端 API

调用流程如下：

```text
用户操作页面
   ↓
Page 调用 Service
   ↓
Service 使用 ApiClient 发起 HTTP 请求
   ↓
请求头自动附带 JWT
   ↓
Spring Boot 返回 JSON
   ↓
Model 解析 JSON
   ↓
页面更新状态并渲染结果
```

### 6.5 token 如何保存和携带

推荐实现方式：

- 登录成功后，前端将 JWT 保存到 `flutter_secure_storage`
- 每次请求时，通过拦截器自动从本地读取 token
- 在请求头中加入：
  `Authorization: Bearer <token>`
- token 失效时跳转登录页
- 为提高安全性，不建议将 token 明文存放在普通 SharedPreferences 中

---

## 7. 后端架构设计

### 7.1 Spring Boot 分层架构

本项目后端采用标准分层架构：

```text
Controller -> Service -> Repository -> MySQL
             ↑
           DTO/VO
             ↑
           Entity
```

### 7.2 各层职责说明

| 层级 | 职责 |
|---|---|
| Controller | 接收 HTTP 请求、参数校验入口、返回统一响应 |
| Service | 承担核心业务逻辑、事务管理、规则判断 |
| Repository | 负责数据库访问，使用 Spring Data JPA 操作实体 |
| Entity | 数据库表实体映射 |
| DTO | 请求参数和响应对象封装，避免直接暴露 Entity |
| Security | JWT 校验、登录认证、权限控制 |
| Exception | 全局异常处理和错误码管理 |

### 7.3 后端目录结构

```text
src/main/java/com/ankang/helper/
├── AnkangHelperApplication.java
├── common/
│   ├── api/
│   │   ├── ApiResponse.java
│   │   └── ResultCode.java
│   ├── exception/
│   │   └── GlobalExceptionHandler.java
│   └── util/
│       ├── JwtUtil.java
│       └── DateUtil.java
├── config/
│   ├── SecurityConfig.java
│   └── WebMvcConfig.java
├── controller/
│   ├── AuthController.java
│   ├── UserController.java
│   ├── ProfileController.java
│   ├── RecordController.java
│   ├── ReminderController.java
│   ├── EmergencyController.java
│   ├── ReportController.java
│   ├── AdviceController.java
│   └── AiController.java
├── dto/
│   ├── auth/
│   ├── profile/
│   ├── record/
│   ├── reminder/
│   ├── emergency/
│   ├── report/
│   └── advice/
├── entity/
│   ├── User.java
│   ├── HealthProfile.java
│   ├── HealthRecord.java
│   ├── Reminder.java
│   ├── Notification.java
│   ├── EmergencyContact.java
│   ├── EmergencyEvent.java
│   └── QaHistory.java
├── repository/
│   ├── UserRepository.java
│   ├── HealthProfileRepository.java
│   ├── HealthRecordRepository.java
│   ├── ReminderRepository.java
│   ├── NotificationRepository.java
│   ├── EmergencyContactRepository.java
│   ├── EmergencyEventRepository.java
│   └── QaHistoryRepository.java
├── security/
│   ├── JwtAuthenticationFilter.java
│   ├── CustomUserDetailsService.java
│   └── LoginUser.java
└── service/
    ├── AuthService.java
    ├── UserService.java
    ├── ProfileService.java
    ├── RecordService.java
    ├── ReminderService.java
    ├── EmergencyService.java
    ├── ReportService.java
    ├── AdviceService.java
    └── AiService.java
```

### 7.4 JWT 鉴权流程

```text
用户登录
   ↓
后端校验用户名和密码
   ↓
生成 JWT 并返回给客户端
   ↓
客户端保存 JWT
   ↓
后续请求携带 Authorization: Bearer token
   ↓
JwtAuthenticationFilter 校验 token
   ↓
校验通过后将用户身份写入 SecurityContext
   ↓
Controller 执行业务逻辑
```

### 7.5 统一返回格式

推荐统一返回格式如下：

```json
{
  "code": 200,
  "message": "success",
  "data": {}
}
```

错误返回示例：

```json
{
  "code": 401,
  "message": "未登录或令牌失效",
  "data": null
}
```

### 7.6 异常处理

系统采用全局异常处理机制：

- 参数校验异常统一处理
- 业务异常统一封装返回
- 数据不存在异常统一处理
- 权限不足返回 403
- token 失效返回 401
- 系统异常返回 500，避免暴露堆栈细节

---

## 8. 数据库设计

> 说明：文档中沿用 `user` 作为表名，实际编码时也可使用 `sys_user` 避免与系统表命名混淆。

### 8.1 `user` 用户表

| 字段名 | 类型 | 是否为空 | 说明 |
|---|---|---|---|
| id | BIGINT | 否 | 主键 |
| username | VARCHAR(50) | 否 | 用户名，唯一 |
| password | VARCHAR(255) | 否 | 加密后的密码 |
| phone | VARCHAR(20) | 是 | 手机号 |
| nickname | VARCHAR(50) | 是 | 昵称 |
| gender | TINYINT | 是 | 性别，0未知1男2女 |
| birth_date | DATE | 是 | 出生日期 |
| avatar_url | VARCHAR(255) | 是 | 头像地址 |
| status | TINYINT | 否 | 账号状态，1正常0禁用 |
| created_at | DATETIME | 否 | 创建时间 |
| updated_at | DATETIME | 否 | 更新时间 |

关键索引：

- `UNIQUE INDEX uk_user_username(username)`
- `INDEX idx_user_phone(phone)`

### 8.2 `health_profile` 健康档案表

| 字段名 | 类型 | 是否为空 | 说明 |
|---|---|---|---|
| id | BIGINT | 否 | 主键 |
| user_id | BIGINT | 否 | 用户 ID |
| height_cm | DECIMAL(5,2) | 是 | 身高 |
| weight_kg | DECIMAL(5,2) | 是 | 体重 |
| blood_type | VARCHAR(10) | 是 | 血型 |
| chronic_disease | VARCHAR(255) | 是 | 慢病类型，可逗号分隔或拆表扩展 |
| allergy_history | VARCHAR(500) | 是 | 过敏史 |
| medical_history | VARCHAR(500) | 是 | 既往病史 |
| emergency_note | VARCHAR(500) | 是 | 紧急备注 |
| created_at | DATETIME | 否 | 创建时间 |
| updated_at | DATETIME | 否 | 更新时间 |

关键索引：

- `UNIQUE INDEX uk_profile_user(user_id)`

### 8.3 `health_record` 健康记录表

| 字段名 | 类型 | 是否为空 | 说明 |
|---|---|---|---|
| id | BIGINT | 否 | 主键 |
| user_id | BIGINT | 否 | 用户 ID |
| type | VARCHAR(30) | 否 | 指标类型，如 blood_pressure、heart_rate、blood_glucose、weight |
| systolic | INT | 是 | 收缩压，血压记录时使用 |
| diastolic | INT | 是 | 舒张压，血压记录时使用 |
| value | DECIMAL(10,2) | 是 | 通用数值，例如心率、体重、血糖 |
| unit | VARCHAR(20) | 是 | 单位，如 bpm、kg、mmol/L |
| status | VARCHAR(20) | 是 | normal、warning、danger |
| source | VARCHAR(20) | 是 | manual、device |
| recorded_at | DATETIME | 否 | 记录时间 |
| remark | VARCHAR(255) | 是 | 备注 |
| created_at | DATETIME | 否 | 创建时间 |

关键索引：

- `INDEX idx_record_user_type_time(user_id, type, recorded_at)`
- `INDEX idx_record_user_time(user_id, recorded_at)`

### 8.4 `reminder` 提醒表

| 字段名 | 类型 | 是否为空 | 说明 |
|---|---|---|---|
| id | BIGINT | 否 | 主键 |
| user_id | BIGINT | 否 | 用户 ID |
| title | VARCHAR(100) | 否 | 提醒标题 |
| reminder_type | VARCHAR(30) | 否 | medicine、blood_pressure、blood_glucose、checkup、followup |
| repeat_type | VARCHAR(20) | 否 | daily、weekly、once |
| remind_time | DATETIME | 否 | 提醒时间 |
| weekdays | VARCHAR(20) | 是 | 周重复信息，如 1,3,5 |
| enabled | TINYINT | 否 | 是否启用 |
| note | VARCHAR(255) | 是 | 备注 |
| created_at | DATETIME | 否 | 创建时间 |
| updated_at | DATETIME | 否 | 更新时间 |

关键索引：

- `INDEX idx_reminder_user_enabled(user_id, enabled)`
- `INDEX idx_reminder_user_time(user_id, remind_time)`

### 8.5 `notification` 通知消息表

| 字段名 | 类型 | 是否为空 | 说明 |
|---|---|---|---|
| id | BIGINT | 否 | 主键 |
| user_id | BIGINT | 否 | 用户 ID |
| title | VARCHAR(100) | 否 | 消息标题 |
| content | VARCHAR(500) | 否 | 消息内容 |
| category | VARCHAR(30) | 否 | reminder、warning、system |
| is_read | TINYINT | 否 | 是否已读 |
| related_id | BIGINT | 是 | 关联业务 ID |
| created_at | DATETIME | 否 | 创建时间 |

关键索引：

- `INDEX idx_notification_user_read(user_id, is_read, created_at)`

### 8.6 `emergency_contact` 紧急联系人表

| 字段名 | 类型 | 是否为空 | 说明 |
|---|---|---|---|
| id | BIGINT | 否 | 主键 |
| user_id | BIGINT | 否 | 用户 ID |
| name | VARCHAR(50) | 否 | 联系人姓名 |
| relation | VARCHAR(50) | 是 | 与用户关系 |
| phone | VARCHAR(20) | 否 | 联系电话 |
| is_primary | TINYINT | 否 | 是否为首要联系人 |
| created_at | DATETIME | 否 | 创建时间 |
| updated_at | DATETIME | 否 | 更新时间 |

关键索引：

- `INDEX idx_contact_user(user_id)`

### 8.7 `emergency_event` 紧急事件表

| 字段名 | 类型 | 是否为空 | 说明 |
|---|---|---|---|
| id | BIGINT | 否 | 主键 |
| user_id | BIGINT | 否 | 用户 ID |
| event_type | VARCHAR(30) | 否 | sos、auto_warning |
| latitude | DECIMAL(10,6) | 是 | 纬度 |
| longitude | DECIMAL(10,6) | 是 | 经度 |
| address | VARCHAR(255) | 是 | 位置描述 |
| trigger_reason | VARCHAR(255) | 是 | 触发原因 |
| status | VARCHAR(20) | 否 | pending、processed、closed |
| created_at | DATETIME | 否 | 创建时间 |
| processed_at | DATETIME | 是 | 处理时间 |

关键索引：

- `INDEX idx_event_user_time(user_id, created_at)`
- `INDEX idx_event_type_status(event_type, status)`

### 8.8 `qa_history` 智能问答历史表，可选

| 字段名 | 类型 | 是否为空 | 说明 |
|---|---|---|---|
| id | BIGINT | 否 | 主键 |
| user_id | BIGINT | 否 | 用户 ID |
| question | VARCHAR(1000) | 否 | 用户问题 |
| answer | TEXT | 否 | 模型回答 |
| source_summary | VARCHAR(1000) | 是 | 检索来源摘要 |
| created_at | DATETIME | 否 | 创建时间 |

关键索引：

- `INDEX idx_qa_user_time(user_id, created_at)`

### 8.9 表关系说明

```text
user 1 --- 1 health_profile
user 1 --- n health_record
user 1 --- n reminder
user 1 --- n notification
user 1 --- n emergency_contact
user 1 --- n emergency_event
user 1 --- n qa_history
```

---

## 9. 接口设计

### 9.1 认证模块接口

#### 9.1.1 POST `/api/auth/register`

功能说明：用户注册

请求示例：

```json
{
  "username": "zhangsan",
  "password": "123456",
  "phone": "13800138000",
  "nickname": "张三"
}
```

返回示例：

```json
{
  "code": 200,
  "message": "注册成功",
  "data": {
    "userId": 1
  }
}
```

#### 9.1.2 POST `/api/auth/login`

功能说明：用户登录并获取 JWT

请求示例：

```json
{
  "username": "zhangsan",
  "password": "123456"
}
```

返回示例：

```json
{
  "code": 200,
  "message": "登录成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9.xxx",
    "tokenType": "Bearer",
    "expiresIn": 7200,
    "user": {
      "id": 1,
      "username": "zhangsan",
      "nickname": "张三"
    }
  }
}
```

### 9.2 用户模块接口

#### 9.2.1 GET `/api/user/me`

功能说明：获取当前登录用户信息

请求头：

```text
Authorization: Bearer <token>
```

返回示例：

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": 1,
    "username": "zhangsan",
    "nickname": "张三",
    "phone": "13800138000"
  }
}
```

### 9.3 健康档案模块接口

#### 9.3.1 GET `/api/profile`

功能说明：获取当前用户健康档案

返回示例：

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "heightCm": 168.0,
    "weightKg": 65.5,
    "bloodType": "A",
    "chronicDisease": "高血压",
    "allergyHistory": "无",
    "medicalHistory": "无"
  }
}
```

#### 9.3.2 PUT `/api/profile`

功能说明：更新健康档案

请求示例：

```json
{
  "heightCm": 168.0,
  "weightKg": 65.5,
  "bloodType": "A",
  "chronicDisease": "高血压",
  "allergyHistory": "青霉素过敏",
  "medicalHistory": "2年前住院治疗高血压"
}
```

返回示例：

```json
{
  "code": 200,
  "message": "档案更新成功",
  "data": null
}
```

### 9.4 健康记录模块接口

#### 9.4.1 POST `/api/records`

功能说明：新增健康记录

请求示例一，血压记录：

```json
{
  "type": "blood_pressure",
  "systolic": 145,
  "diastolic": 92,
  "unit": "mmHg",
  "recordedAt": "2026-07-06 08:30:00",
  "remark": "早餐前测量"
}
```

请求示例二，血糖记录：

```json
{
  "type": "blood_glucose",
  "value": 7.8,
  "unit": "mmol/L",
  "recordedAt": "2026-07-06 07:50:00",
  "remark": "空腹"
}
```

返回示例：

```json
{
  "code": 200,
  "message": "记录新增成功",
  "data": {
    "recordId": 1001,
    "status": "warning"
  }
}
```

#### 9.4.2 GET `/api/records`

功能说明：分页查询健康记录

请求参数示例：

```text
type=blood_pressure&startDate=2026-07-01&endDate=2026-07-06&page=1&size=10
```

返回示例：

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "total": 25,
    "list": [
      {
        "id": 1001,
        "type": "blood_pressure",
        "systolic": 145,
        "diastolic": 92,
        "unit": "mmHg",
        "status": "warning",
        "recordedAt": "2026-07-06 08:30:00"
      }
    ]
  }
}
```

#### 9.4.3 GET `/api/records/trend`

功能说明：获取趋势图数据

请求参数示例：

```text
type=heart_rate&range=7d
```

返回示例：

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "type": "heart_rate",
    "range": "7d",
    "points": [
      { "time": "2026-07-01", "value": 78 },
      { "time": "2026-07-02", "value": 81 },
      { "time": "2026-07-03", "value": 76 }
    ],
    "avg": 78.3,
    "max": 85,
    "min": 74,
    "abnormalCount": 1
  }
}
```

### 9.5 提醒模块接口

#### 9.5.1 POST `/api/reminders`

功能说明：新增提醒

请求示例：

```json
{
  "title": "早晨降压药",
  "reminderType": "medicine",
  "repeatType": "daily",
  "remindTime": "2026-07-06 08:00:00",
  "enabled": true,
  "note": "饭后服用"
}
```

返回示例：

```json
{
  "code": 200,
  "message": "提醒创建成功",
  "data": {
    "reminderId": 2001
  }
}
```

#### 9.5.2 GET `/api/reminders`

功能说明：查询提醒列表

返回示例：

```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "id": 2001,
      "title": "早晨降压药",
      "reminderType": "medicine",
      "repeatType": "daily",
      "remindTime": "2026-07-06 08:00:00",
      "enabled": true
    }
  ]
}
```

### 9.6 紧急救援模块接口

#### 9.6.1 POST `/api/emergency/sos`

功能说明：用户发起一键呼救

请求示例：

```json
{
  "latitude": 31.230416,
  "longitude": 121.473701,
  "address": "上海市黄浦区某街道",
  "triggerReason": "突发胸闷头晕"
}
```

返回示例：

```json
{
  "code": 200,
  "message": "SOS 已提交",
  "data": {
    "eventId": 3001,
    "status": "pending"
  }
}
```

#### 9.6.2 GET `/api/emergency/contacts`

功能说明：获取紧急联系人列表

返回示例：

```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "id": 1,
      "name": "李四",
      "relation": "儿子",
      "phone": "13900000000",
      "isPrimary": true
    }
  ]
}
```

### 9.7 报表与建议模块接口

#### 9.7.1 GET `/api/reports/weekly`

功能说明：获取周报

请求参数示例：

```text
weekStart=2026-06-29
```

返回示例：

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "weekStart": "2026-06-29",
    "weekEnd": "2026-07-05",
    "summary": "本周血压整体偏高，建议坚持监测并关注作息。",
    "indicators": {
      "bloodPressure": {
        "abnormalCount": 3,
        "avgSystolic": 142
      },
      "bloodGlucose": {
        "abnormalCount": 1,
        "avgValue": 6.9
      }
    }
  }
}
```

#### 9.7.2 GET `/api/advice`

功能说明：获取个性化健康建议

返回示例：

```json
{
  "code": 200,
  "message": "success",
  "data": [
    "最近3天收缩压持续偏高，建议减少高盐饮食并按时服药。",
    "本周血压记录较完整，建议继续保持每日固定时间测量。",
    "本系统建议仅供参考，若持续异常请及时就医。"
  ]
}
```

### 9.8 智能问答模块接口，可选

#### 9.8.1 POST `/api/ai/chat`

功能说明：提交健康问题并获取回答

请求示例：

```json
{
  "question": "高血压患者晚上头晕应该注意什么？"
}
```

返回示例：

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "answer": "建议先保持休息，避免剧烈活动，复测血压。如症状持续或明显加重，请及时就医。",
    "sourceSummary": "来源于高血压日常管理知识库",
    "disclaimer": "回答仅供健康管理参考，不能替代医生诊断和治疗建议。"
  }
}
```

---

## 10. 核心业务流程

### 10.1 用户登录流程

```text
用户打开登录页
   ↓
输入用户名和密码
   ↓
Flutter 调用 POST /api/auth/login
   ↓
Spring Boot 校验账号密码
   ↓
校验成功，生成 JWT
   ↓
返回 token 和用户信息
   ↓
Flutter 保存 token
   ↓
跳转首页
```

### 10.2 用户记录健康数据流程

```text
用户进入健康记录页
   ↓
选择指标类型并填写数据
   ↓
Flutter 调用 POST /api/records
   ↓
Spring Boot 校验参数合法性
   ↓
Service 判断是否异常
   ↓
写入 MySQL health_record
   ↓
返回记录结果和状态
   ↓
Flutter 刷新历史记录和趋势图
```

### 10.3 健康数据异常预警流程

```text
用户提交健康记录
   ↓
后端根据规则判断是否异常
   ↓
若指标超阈值，则标记 warning 或 danger
   ↓
若满足连续异常条件，则生成预警事件
   ↓
写入 emergency_event 或 notification
   ↓
前端展示异常提示与健康建议
```

### 10.4 一键呼救流程

```text
用户点击 SOS 按钮
   ↓
App 获取当前位置
   ↓
Flutter 调用 POST /api/emergency/sos
   ↓
Spring Boot 记录紧急事件
   ↓
返回事件编号和处理状态
   ↓
前端提示“已发送求助请求”
   ↓
后续可扩展通知紧急联系人
```

### 10.5 健康趋势分析流程

```text
用户进入趋势页
   ↓
选择指标和时间范围
   ↓
Flutter 调用 GET /api/records/trend
   ↓
Spring Boot 聚合统计数据
   ↓
返回趋势点、均值、异常次数
   ↓
Flutter 渲染折线图和统计卡片
```

### 10.6 智能问答流程，可选

```text
用户输入健康问题
   ↓
Flutter 调用 POST /api/ai/chat
   ↓
Spring Boot 转发到 AI 服务
   ↓
FastAPI 检索知识库并生成回答
   ↓
返回答案、来源摘要、免责声明
   ↓
Spring Boot 记录 qa_history
   ↓
Flutter 展示回答内容
```

---

## 11. 非功能性需求设计

### 11.1 客户端适配不同分辨率和尺寸

- Flutter 使用响应式布局方案
- 尽量采用 `Expanded`、`Flexible`、`MediaQuery`、`LayoutBuilder` 等机制
- 文字尺寸与按钮区域适当放大，提升老人用户可用性
- 关键功能入口如 SOS 按钮应保持醒目且在小屏设备上也易于点击

### 11.2 数据量不少于 10k

- 数据库设计中为高频查询字段建立索引
- 健康记录查询采用分页加载
- 趋势图接口按时间范围聚合，避免一次返回过多记录
- 可通过初始化脚本导入不少于 10k 条测试数据验证性能

### 11.3 100 并发场景下响应时间小于 3 秒

- 对登录、健康记录查询、趋势分析、提醒查询等核心接口进行压测
- 后端采用连接池与合理线程池配置
- 查询接口避免全表扫描
- 使用必要索引和时间范围过滤
- 趋势报表查询可引入轻量缓存或统计结果缓存

### 11.4 安全性

- JWT 鉴权
- 密码加密存储
- 用户数据按 user_id 隔离
- 全接口参数校验
- 敏感信息脱敏返回
- 生产环境使用 HTTPS

### 11.5 可维护性

- 前端分层清晰，页面与服务解耦
- 后端采用 Controller、Service、Repository 分层
- 统一返回结构与异常处理
- 业务规则集中在 Service 层，便于修改和扩展

### 11.6 可扩展性

- 模块边界清晰，可增加更多健康指标
- 可扩展设备接入，如智能手环、血压计
- 可扩展通知通道，如短信、推送
- AI 模块独立部署，不影响基础业务系统

---

## 12. 性能测试方案

### 12.1 测试目标

验证系统在以下条件下的可用性与稳定性：

- 健康数据总量不少于 10k
- 并发用户数达到 100
- 核心接口平均响应时间控制在 3 秒以内

### 12.2 测试工具

- Apache JMeter

### 12.3 测试数据准备

- 构造 100 个测试用户
- 每个用户写入 100 条健康记录
- 总健康记录数达到或超过 10,000 条
- 覆盖血压、血糖、心率、体重等多类数据

### 12.4 重点测试接口

- `POST /api/auth/login`
- `GET /api/records`
- `GET /api/records/trend`
- `GET /api/reminders`
- `GET /api/reports/weekly`

### 12.5 测试场景设计

| 场景 | 并发数 | 持续时间 | 指标 |
|---|---|---|---|
| 登录接口压测 | 100 | 1 分钟 | 平均响应时间、错误率 |
| 健康记录查询 | 100 | 2 分钟 | 平均响应时间、吞吐量 |
| 趋势图查询 | 100 | 2 分钟 | 聚合查询耗时 |
| 提醒列表查询 | 100 | 1 分钟 | 稳定性与错误率 |
| 周报查询 | 50 | 2 分钟 | 报表接口性能 |

### 12.6 性能优化措施

- 为 `health_record(user_id, type, recorded_at)` 建立联合索引
- 所有列表类接口采用分页
- 查询仅返回必要字段，避免大对象冗余
- 周报和趋势分析可以增加缓存
- 使用数据库连接池提高吞吐能力
- 对高频统计操作进行 SQL 优化或预聚合设计

---

## 13. 安全性设计

### 13.1 JWT 登录认证

- 用户登录成功后由后端签发 JWT
- 客户端每次请求携带 token
- 后端校验 token 是否有效和是否过期
- 无效 token 直接拦截，防止未授权访问

### 13.2 密码加密存储

- 密码采用 BCrypt 加密
- 数据库中不存储明文密码
- 后端比较密码时使用加密算法匹配

### 13.3 用户只能访问自己的健康数据

- 每次请求从 JWT 中获取当前用户 ID
- 查询、修改、删除操作均附带当前用户身份条件
- 禁止通过传入他人 user_id 访问他人数据

### 13.4 后端参数校验

- 使用 `@NotNull`、`@NotBlank`、`@Size`、`@Min`、`@Max` 等注解校验参数
- 对血压、心率、血糖数值范围进行合理校验
- 对日期格式、手机号格式等进行格式约束

### 13.5 敏感信息保护

- 返回用户信息时避免返回密码字段
- 手机号等敏感字段可视情况脱敏展示
- 日志中避免打印完整 token 和隐私数据

### 13.6 健康建议免责声明

- 所有建议与问答输出必须加注说明
- 示例说明：**本系统提供的健康建议仅供日常管理参考，不能替代医生诊断、处方和治疗意见**

---

## 14. 项目目录结构

### 14.1 Flutter 前端目录结构

```text
UIPrototype/
├── android/
├── lib/
├── test/
├── pubspec.yaml
└── README.md
```

### 14.2 Spring Boot 后端目录结构

```text
backend/
├── src/
│   ├── main/
│   │   ├── java/
│   │   └── resources/
│   └── test/
├── pom.xml
└── README.md
```

### 14.3 可选 AI 服务目录结构

```text
ai-service/
├── app/
│   ├── main.py
│   ├── routes/
│   ├── services/
│   ├── schemas/
│   └── rag/
├── knowledge_base/
├── requirements.txt
└── README.md
```

---

## 15. 开发计划

### 15.1 第一阶段：基础框架、登录注册、数据库设计

- 搭建 Flutter 项目和 Spring Boot 项目
- 配置 MySQL 数据库连接
- 完成用户表与基础表设计
- 实现注册、登录、JWT 鉴权

### 15.2 第二阶段：健康档案与健康数据管理

- 实现健康档案查看与编辑
- 实现健康记录新增与查询
- 实现健康记录列表与趋势图页面

### 15.3 第三阶段：提醒与紧急救援

- 实现提醒管理模块
- 实现通知消息模块
- 实现紧急联系人管理
- 实现一键 SOS 呼救流程

### 15.4 第四阶段：趋势分析与健康建议

- 完成趋势统计接口
- 完成周报和月报生成功能
- 完成规则驱动的个性化建议模块

### 15.5 第五阶段：智能问答扩展

- 搭建 FastAPI AI 服务
- 建立基础健康知识库
- 对接 RAG 检索流程
- 实现 `/api/ai/chat` 接口联调

### 15.6 第六阶段：测试、压测、部署和答辩材料整理

- 编写功能测试用例
- 使用 JMeter 完成接口压测
- 整理系统截图、流程图、架构图
- 准备课程答辩 PPT 和演示脚本

---

## 16. 项目亮点

### 16.1 面向老人和慢病患者的实际应用场景

本项目并非通用记事类应用，而是围绕老年人和慢病患者的真实需求展开，场景明确，具有较强的现实意义和课程项目价值。

### 16.2 Flutter + Spring Boot 前后端分离架构

系统采用清晰的前后端分离设计，符合现代软件工程实践。Flutter 负责交互，Spring Boot 负责业务，MySQL 负责存储，结构清晰，便于团队协作和后续扩展。

### 16.3 健康数据趋势分析

系统不仅支持数据录入，还能够进行血压、血糖、心率等指标的趋势统计与图表展示，提升项目的分析能力和展示效果。

### 16.4 异常数据自动预警

系统可根据阈值和连续异常规则自动标记风险记录，并生成预警事件或通知，这一功能体现了系统的智能辅助能力。

### 16.5 一键紧急救援

SOS 一键呼救是项目的重要特色，能够结合位置上报和紧急联系人管理，增强系统的安全保障价值。

### 16.6 可扩展 RAG 智能问答

在基础版本稳定的前提下，系统预留了独立 AI 服务扩展架构，可接入 RAG 问答与健康知识库，体现系统的前瞻性和扩展能力。

### 16.7 满足 10k 数据量和 100 并发性能要求

通过索引、分页、聚合查询优化与 JMeter 压测方案，项目具备面向课程验收的性能设计依据，体现工程化思维。

---

## 17. 总结

“安康助手”项目面向老人与慢病患者的健康管理和安全救援需求，构建了一个以 Flutter App 为前端、Spring Boot 为后端、MySQL 为数据库的完整前后端分离系统。该系统具备健康档案管理、健康数据记录、健康提醒、紧急救援、趋势分析和个性化建议等核心功能，既满足了课程项目对完整软件系统的要求，也具有较强的现实应用意义。

从软件工程角度看，本项目具有以下特点：

- 需求来源明确，目标用户清晰
- 架构设计规范，职责划分合理
- 数据库与接口设计完整，便于实现和测试
- 具备性能、安全、可维护、可扩展等工程化考虑
- 预留 AI 智能问答扩展空间，能够支持后续迭代升级

因此，本项目既适合作为软件工程课程的开发实践项目，也适合作为课程答辩和文档提交材料使用。若按计划完成各阶段开发与测试工作，可形成一套功能完整、结构规范、展示效果良好的健康安全智能助手系统。
