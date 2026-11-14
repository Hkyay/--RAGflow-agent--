# 深维学院 RAG 智能问答（单容器部署版）

一个容器内运行全部服务：PostgreSQL 15 + Elasticsearch 8.11.3 + Redis 7 + FastAPI 后端 + Nginx 托管 React 前端（端口 7860）。

**主推方案：Sealos 公有云**（大陆直连、按量计费、有持久盘）。Hugging Face Spaces 方案因免费配额限制降为附录。

---

## 方案总览

```
本地 docker build ──push──▶ 阿里云 ACR（公开仓库）
                                   │
Sealos App Launchpad ◀──pull───────┘
        │
        ├── 容器端口 7860 → 自动分配公网域名 *.sealos.run
        ├── 持久卷挂 /home/user（PG 数据 + ES 索引 + 上传文档）
        └── 环境变量 DASHSCOPE_API_KEY
```

## 前置条件

| 项 | 说明 |
|----|------|
| Docker Desktop | 本地运行，用于构建镜像 |
| 阿里云 ACR 个人版 | 开通实例（免费）→ 创建命名空间与公开仓库 |
| sealos.run 账号 | 手机号/GitHub 注册，充值少量额度（2C4G 约 0.1~0.2 元/小时，演示几充 10 元以内） |

## 第 1 步：本地构建镜像

在项目根目录准备构建目录（排除密钥与大文件）：

```powershell
$ctx = "$env:TEMP\kyay-ragflow-space"
git clone <本项目> $ctx   # 或 robocopy 组装，见下
robocopy "deploy\hf-space" $ctx /E
robocopy "backend"  "$ctx\backend"  /E /XD nltk_data __pycache__ .cache storage /XF .env "*.env"
robocopy "frontend" "$ctx\frontend" /E /XD node_modules __pycache__ .cache /XF .env

docker build -t kyay-ragflow:v1 $ctx
```

> Dockerfile 已内置国内加速：基础镜像走 DaoCloud、apt 清华源、pip 阿里源、npm npmmirror。全量构建约 20~40 分钟。

## 第 2 步：推送到阿里云 ACR

```powershell
# 登录（用户名 = ACR 控制台「访问凭证」页显示的登录用户名；密码 = 在该页设置的固定密码，与阿里云账号密码无关）
# Windows PowerShell 下管道传密码易出编码问题，建议交互式：
docker login crpi-xxxxxxxx.cn-hangzhou.personal.cr.aliyuncs.com -u <登录用户名>

docker tag kyay-ragflow:v1 crpi-xxxxxxxx.cn-hangzhou.personal.cr.aliyuncs.com/<命名空间>/<仓库名>:v1
docker push crpi-xxxxxxxx.cn-hangzhou.personal.cr.aliyuncs.com/<命名空间>/<仓库名>:v1
```

> 仓库必须设为**公开**，否则 Sealos 拉取需要额外凭证。

## 第 3 步：Sealos 部署

1. 打开 https://sealos.run 登录 → 进入控制台
2. 打开 **应用管理（App Launchpad）** → **新建应用**
3. 按下表填写：

   | 配置项 | 值 |
   |--------|-----|
   | 应用名 | `ragflow-demo`（任意） |
   | 镜像 | `crpi-xxxxxxxx.cn-hangzhou.personal.cr.aliyuncs.com/<命名空间>/<仓库名>:v1` |
   | CPU | 2 核 |
   | 内存 | 4 Gi |
   | 容器端口 | `7860`，协议 HTTP，**开启外网访问**（自动分配 `*.sealos.run` 域名） |
   | 环境变量 | `DASHSCOPE_API_KEY` = 你的百炼 API Key |
   | 持久化存储卷 | 挂载路径 `/home/user`，容量 `10 Gi`（PG 库 + ES 索引 + 上传文档都在这下面） |

4. 点**部署** → 等状态变 **Running**（首次拉镜像约 5~15 分钟）
5. 访问分配的外网域名即可使用

> 为什么挂 `/home/user` 就够：容器内 PostgreSQL 数据目录、Elasticsearch 数据目录、Redis 持久化全部位于 `/home/user` 之下，一个卷全部覆盖。容器重启/重建后数据不丢。

## 第 4 步：验证

1. 打开 `https://<分配的域名>.sealos.run`
2. 注册账号 → 上传文档 → 等待解析完成 → 提问
3. 后端 API 文档：`https://<域名>/api/docs`

## 须知

- **费用**：2C4G 按量计费约 0.1~0.2 元/小时；演示结束在 App Launchpad 停止应用即停止计费。
- **首次启动**：entrypoint 会自动初始化 PostgreSQL、执行 dbinit（建库 + alembic 迁移），首次访问慢 1~2 分钟属正常。
- **密钥安全**：镜像内不含任何 API Key，`DASHSCOPE_API_KEY` 由 Sealos 环境变量注入；上传到镜像仓库的是公开清洗后的代码。
- **ES 内存**：容器内 ES 固定 512m 堆，4G 内存配额足够；不要低于 3G。

---

## 附录：Hugging Face Spaces 方案（备选）

> 免费配额（cpu-basic）当前 limit=0，会被暂停（Quota exceeded）；付费需绑卡。如需此方案：

1. New Space（SDK 选 **Docker**，Public）→ 仓库根放本目录全部文件（`README.md` 顶部需保留 HF front-matter：`sdk: docker`、`app_port: 7860`）
2. Space Settings → Secrets 添加 `DASHSCOPE_API_KEY`
3. push 后自动构建 10~20 分钟，访问 `https://<用户名>-<space名>.hf.space`
4. **注意**：大陆访问 `*.hf.space` 需代理；免费 Space 无持久盘，重建后数据清空；48h 无访问休眠

本目录即 HF Space 布局：`backend/`、`frontend/`、Dockerfile、supervisord.conf、nginx-space.conf、entrypoint.sh、dbinit.sh、.gitattributes（LFS 跟踪二进制）。
