# 安康助手 Flutter 公共框架

本目录已按 `FLUTTER_PUBLIC_FRAMEWORK_PLAN.md` 搭建 Flutter 公共框架，包含统一目录、路由、主题、网络请求、token 管理、通用组件、模型和业务页面壳子。

## 运行

当前阶段这是 Flutter 公共框架 demo，主要用于团队先查看页面框架、目录规范和基础能力。推荐先在 WSL/Ubuntu 中用 Flutter Web Server 运行，不要求配置 Android Studio 或 Android SDK。

```bash
cd /home/houyuze/SEproj
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081
```

启动后在 Windows 浏览器访问：

```text
http://localhost:8081
```

详细环境配置和当前状态见 `TEAM_ENVIRONMENT.md`。

开发环境默认 API 地址在 `lib/config/api_config.dart`：

```dart
static const String devBaseUrl = 'http://10.0.2.2:8080/api';
```

Android 模拟器访问宿主机后端时使用 `10.0.2.2`。真机调试时请改为电脑局域网 IP。

## 协作约定

- 页面放在 `lib/pages`
- 接口封装放在 `lib/services`
- 数据结构放在 `lib/models`
- 公共 UI 放在 `lib/widgets`
- 工具函数放在 `lib/utils`
- 页面跳转统一使用 `AppRoutes` 常量
- 网络请求统一通过 `ApiClient`
- token 统一通过 `TokenStorage` 管理

## 家庭协同照护模式

Flutter 仍然是同一个 App，没有拆成独立家属 App，也不要求家属使用病人账号。病人端现有首页、健康数据、趋势、提醒、SOS、Agent 和个人信息管理功能保持不变。

“我的”页新增“家庭照护”入口：

- 病人可生成家属绑定码。
- 家属可输入绑定码绑定被照护者。
- 家属可查看绑定病人的健康摘要、健康记录、趋势、提醒完成情况和 SOS 记录。
- 家属可进入“咨询 Agent”，基于该病人的授权健康上下文提问。

前端 family 页面只调用 `/family/**` 只读接口，不展示新增健康数据、编辑档案、修改提醒、删除记录、修改紧急联系人或直接发起 SOS 的入口。数据由后端根据绑定关系读取 patient 原始数据源，前端不使用 family mock 数据。

## Health Action Agent 前端

普通 Agent 和家属版 Agent 都支持后端返回的 `pendingAction`。聊天气泡内会展示 Action 确认卡片，用户点击确认或取消后调用：

- `POST /api/agent/actions/confirm`

前端只负责展示和确认，不直接写健康数据、不创建提醒、不触发 SOS、不通知家属。执行结果会在卡片中展示：

- 健康数据保存结果和风险预警。
- 健康计划创建的提醒。
- SOS 预案、附近医院、绑定家属和紧急联系人。
- 通知家属消息预览。

家属版页面同样显示 Action 卡片，但后端会拒绝家属录入病人健康数据或修改病人提醒。
