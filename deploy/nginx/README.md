# Nginx 本地反向代理

云服务器、域名和 HTTPS 的完整架构设计见
[`docs/NGINX_ARCHITECTURE_AND_DOMAIN_DEPLOYMENT.md`](../../docs/NGINX_ARCHITECTURE_AND_DOMAIN_DEPLOYMENT.md)。

当前配置用于本地开发：Nginx 在 Docker 中运行，并把请求转发到宿主机
`8080` 端口上的 Spring Boot 后端。

## 启动

先启动 MySQL 和 Nginx：

```powershell
cd D:\SEpro\SE25Project-11
docker compose up -d mysql nginx
```

再在宿主机启动后端：

```powershell
cd D:\SEpro\SE25Project-11\backend
mvn spring-boot:run
```

默认情况下，Nginx 对外监听 `8088`：

```text
http://localhost:8088/api/test/ping
http://localhost:8088/doc.html
```

如需修改宿主机端口，可在启动前设置 `NGINX_PORT`：

```powershell
$env:NGINX_PORT="8089"
docker compose up -d nginx
```

## Flutter 联调

Android 模拟器通过 Nginx 访问后端：

```powershell
cd D:\SEpro\SE25Project-11\UIPrototype
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8088/api
```

Flutter Web 使用：

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8088/api
```

## 检查状态

```powershell
docker compose ps
docker compose logs nginx
```

Nginx 自身健康检查地址：

```text
http://localhost:8088/nginx-health
```

如果 Nginx 返回 `502 Bad Gateway`，表示 Nginx 已启动，但宿主机上的
Spring Boot 后端没有在 `8080` 端口运行。

## 生产部署说明

这份配置只提供 HTTP 本地开发入口。生产环境还应配置域名、TLS 证书、
请求限流、安全响应头和日志轮转。后端容器化后，应把 upstream 地址从
`host.docker.internal:8080` 改为 Compose 服务名，例如 `backend:8080`。
