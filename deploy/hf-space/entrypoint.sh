#!/bin/bash
# HF Spaces 容器入口：初始化目录 -> 导出环境变量 -> 交给 supervisor 托管全部服务
set -e

# ---------- 运行目录 ----------
PGDATA=/home/user/pgdata
mkdir -p "$PGDATA" /home/user/pgsock /home/user/esdata /home/user/eslogs \
         /home/user/supervisor /home/user/nginx-cache

# ---------- 环境变量（单容器内网地址）----------
export PATH="/usr/lib/postgresql/15/bin:$PATH"
export DATABASE_URL="${DATABASE_URL:-postgresql://postgres@127.0.0.1:5432/gsk}"
export ES_HOST="${ES_HOST:-http://127.0.0.1:9200}"
export REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
export REDIS_PORT="${REDIS_PORT:-6379}"
export REDIS_DB="${REDIS_DB:-0}"
export ROOT_PATH="${ROOT_PATH:-}"
export ES_JAVA_OPTS="${ES_JAVA_OPTS:--Xms512m -Xmx512m}"

# ---------- PostgreSQL 首次初始化 ----------
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "[entrypoint] 初始化 PostgreSQL 数据目录..."
    /usr/lib/postgresql/15/bin/initdb -D "$PGDATA" -U postgres \
        --auth-local=trust --auth-host=trust -E UTF8 --locale=C
fi

echo "[entrypoint] 启动 supervisor 托管全部服务..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
