---
title: 深维学院 RAG 智能问答
colorFrom: blue
colorTo: purple
sdk: docker
app_port: 7860
pinned: false
---

# 深维学院 RAG 智能问答（单容器部署版）

一个容器内运行全部服务：PostgreSQL 15 + Elasticsearch 8.11.3 + Redis 7 + FastAPI 后端 + Nginx 托管 React 前端。

## 部署步骤

### 1. 创建 Space
- 登录 https://huggingface.co → New Space
- Space name：如 `ragflow-agent`；SDK 选 **Docker**（Blank 模板）；可见性 Public
- 得到形如 `https://huggingface.co/spaces/<你的用户名>/<Space名>` 的仓库

### 2. 生成 Token
- https://huggingface.co/settings/tokens → New token → 权限选 **Write**

### 3. 本地组装 Space 仓库（在 GitHub 项目根目录执行 PowerShell）
```powershell
# 把 <你的用户名> 和 <Space名> 换成自己的
$space = "$env:TEMP\ragflow-agent-space"
git clone https://<你的HF用户名>:<Write Token>@huggingface.co/spaces/<你的用户名>/<Space名> $space

# 拷贝部署套件 + 前后端源码（排除缓存/密钥/大目录）
robocopy "deploy\hf-space" $space /E
robocopy "backend" "$space\backend" /E /XD nltk_data __pycache__ .cache storage /XF .env "*.env"
robocopy "frontend" "$space\frontend" /E /XD node_modules __pycache__ .cache /XF .env

# 推送（触发 HF 自动构建）
cd $space
git add .
git commit -m "deploy: single-container RAG app"
git push
```

### 4. 设置密钥
Space 页面 → Settings → **Variables and secrets** → New secret：
| Name | Value |
|------|-------|
| `DASHSCOPE_API_KEY` | 你的百炼 API Key |

其余数据库/Elasticsearch/Redis 均绑定 127.0.0.1 且免密（容器内部网络，外界不可达），无需配置。

### 5. 等待构建并访问
- 构建约 10~20 分钟（下载 ES、pip、npm）
- 完成后访问 `https://<你的用户名>-<space名>.hf.space`
- 排查日志：Space 页面 → Logs（Container / Build 两个标签页）

## 须知

- **访问需要科学上网**：`*.hf.space` 在大陆直连不通，演示时讲解者和观众都要有代理。
- **数据不持久**：免费 Space 无持久盘，容器重建/休眠唤醒后上传的文档与索引会清空，重新上传即可。
- **休眠**：48 小时无访问会休眠，首次唤醒需等 1~2 分钟。
- **首次使用**：注册账号 → 上传文档 → 等解析完成 → 提问。
- 后端 API 文档：`https://...hf.space/api/docs`
