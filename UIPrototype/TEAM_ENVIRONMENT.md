# 团队开发环境说明

## 当前项目状态

本项目当前是“安康助手”Flutter 公共框架 demo，不是完整业务成品。现阶段目标是让团队成员先跑通页面框架、路由、主题、网络封装、模型、公共组件和业务页面壳子。

当前推荐运行目标：

- WSL Ubuntu 下运行 Flutter Web demo
- 不要求 Android 模拟器
- 不要求 Android Studio
- 不要求 Android SDK
- 后续上线 Android 时再补 Android 开发和打包环境

## 已验证环境

```text
OS: Ubuntu 24.04.3 LTS on WSL2
Flutter: 3.44.5 stable
Dart: 3.12.2
项目目录: /home/houyuze/SEproj
Flutter SDK: /home/houyuze/dev/flutter
```

Flutter Web Server 已验证可以在 WSL 中监听 `0.0.0.0:8081`，Windows 浏览器可以通过 `http://localhost:8081` 访问。

## 首次环境配置

确认 Flutter 命令可用：

```bash
flutter --version
flutter doctor -v
```

如果 `flutter` 命令不存在，确认 Flutter SDK 的 `bin` 目录已经加入 PATH：

```bash
export PATH="$HOME/dev/flutter/bin:$PATH"
```

建议写入 `~/.bashrc`：

```bash
export PATH="$HOME/dev/flutter/bin:$PATH"
```

启用 Web 支持并预缓存 Web artifacts：

```bash
flutter config --enable-web
flutter precache --web
```

## 启动 Demo

进入项目目录：

```bash
cd /home/houyuze/SEproj
```

安装依赖：

```bash
flutter pub get
```

启动 Web demo：

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081
```

启动成功后会看到类似输出：

```text
lib/main.dart is being served at http://0.0.0.0:8081
```

然后在 Windows 浏览器访问：

```text
http://localhost:8081
```

## 常用运行控制

`flutter run` 启动后，终端里可以使用：

```text
r  热重载
R  热重启
q  停止服务
h  查看帮助
```

## 端口说明

团队统一使用 `8081` 作为 Flutter Web demo 端口：

```bash
--web-port 8081
```

不要使用 `--web-port 8`。`8` 属于低端口范围，Linux 下通常需要特殊权限，也不适合作为开发服务端口。

如果 `8081` 被占用，可以临时换成 `8082`：

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8082
```

对应浏览器访问：

```text
http://localhost:8082
```

## 关于 Web 配置提示

如果启动时看到：

```text
This application is not configured to build on the web.
To add web support to a project, run `flutter create .`.
```

现阶段可以先忽略。只要后面出现：

```text
lib/main.dart is being served at http://0.0.0.0:8081
```

就说明 demo 已经跑起来了。

当前阶段使用 `-d web-server` 只是为了快速查看 demo，不代表项目最终以 Web 上线。后续 Android 上线前再补齐 Android 环境和构建流程。

## 后端地址说明

当前开发环境 API 地址在：

```text
lib/config/api_config.dart
```

默认值：

```dart
static const String devBaseUrl = 'http://10.0.2.2:8080/api';
```

`10.0.2.2` 是 Android 模拟器访问宿主机后端时使用的地址。

如果当前用 Web demo 联调本机后端，通常需要改成：

```dart
static const String devBaseUrl = 'http://localhost:8080/api';
```

如果用 Android 真机联调，需要改成电脑局域网 IP，例如：

```dart
static const String devBaseUrl = 'http://192.168.x.x:8080/api';
```

后端还需要允许跨域请求，否则 Web demo 调接口时会遇到 CORS 问题。

## 测试

运行本地测试：

```bash
cd /home/houyuze/SEproj
flutter test test
```

当前测试已验证通过。

## Android 后续计划

当前不要求配置 Android 环境。后续需要上线 Android 时，再补充：

- Android Studio
- Android SDK
- Android cmdline-tools
- Android licenses
- 模拟器或真机调试
- release 签名配置
- `flutter build apk` 或 `flutter build appbundle`
