# ============================================================
# HF Spaces 单容器全家桶：PostgreSQL + Elasticsearch + Redis
#               + FastAPI 后端 + Nginx 前端（端口 7860）
# ============================================================

# ---------- 阶段 1：构建前端 ----------
FROM node:20-bookworm-slim AS webbuild

WORKDIR /fe
RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ && rm -rf /var/lib/apt/lists/*
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ .
# VITE_API_BASE=/api 让浏览器请求同源 /api/*，由 Nginx 反代到后端（进程环境变量优先于 .env 文件）
RUN VITE_API_BASE=/api VITE_TITLE=深维学院 npm run build

# ---------- 阶段 2：运行镜像 ----------
FROM python:3.11.7-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential python3-dev libgl1 libglu1-mesa libglib2.0-0 \
    supervisor nginx postgresql redis-server curl procps \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default

# Elasticsearch 8.11.3（tarball 自带 JDK，无需另装 Java）
RUN curl -fsSL https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.11.3-linux-x86_64.tar.gz -o /tmp/es.tgz \
    && tar -xzf /tmp/es.tgz -C /opt \
    && mv /opt/elasticsearch-8.11.3 /opt/elasticsearch \
    && rm /tmp/es.tgz

# 后端依赖与代码
WORKDIR /app
COPY backend/app/requirements.txt .
RUN pip install --no-cache-dir --retries 10 --timeout 120 -r requirements.txt
COPY backend/app/ /app/
COPY backend/init.sql /app/init.sql

# 前端静态产物 + 各配置文件
COPY --from=webbuild /fe/dist /var/www/html
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx-space.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /entrypoint.sh
COPY dbinit.sh /app/dbinit.sh

# HF Spaces 以 uid=1000 运行容器，所有运行时要写的目录都交给它
RUN useradd -m -u 1000 user \
    && chmod +x /entrypoint.sh /app/dbinit.sh \
    && mkdir -p /var/lib/nginx/body /var/lib/nginx/fastcgi_temp /var/lib/nginx/proxy_temp \
                /var/lib/nginx/uwsgi_temp /var/lib/nginx/scgi_temp /var/log/nginx \
    && touch /var/run/nginx.pid \
    && chown -R user:user /app /opt/elasticsearch /var/www/html /home/user \
                          /var/lib/nginx /var/log/nginx /var/run/nginx.pid

USER user

EXPOSE 7860
ENTRYPOINT ["/entrypoint.sh"]
