#!/bin/bash
# HF Spaces 容器入口：初始化目录 -> 导出环境变量 -> 交给 supervisor 托管全部服务
set -e

# 云平台（Sealos 等）挂载的持久卷通常是 root 属主，若非 root 直接写会崩；
# 这里以 root 启动时先修正归属，再用 setpriv 降权（exec 方式，保证 PID1 是 supervisord，信号可正常传递）
if [ "$(id -u)" = "0" ] && [ -z "$KYAY_DROPPED" ]; then
    mkdir -p /home/user
    chown -R user:user /home/user
    export KYAY_DROPPED=1
    exec setpriv --reuid=1000 --regid=1000 --clear-groups /bin/bash /entrypoint.sh
fi

# ---------- 运行目录 ----------
PGDATA=/home/user/pgdata
mkdir -p "$PGDATA" /home/user/pgsock /home/user/esdata /home/user/eslogs \
         /home/user/supervisor /home/user/nginx-cache /home/user/storage

# 上传的文档也落到持久盘（后端按 <project_base>/storage/file 存放）
mkdir -p /app/service/core/storage
if [ ! -L /app/service/core/storage ]; then
    rm -rf /app/service/core/storage
    ln -s /home/user/storage /app/service/core/storage
fi

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
# 容器重建后残留的 postmaster.pid 会让 PG 误判"已有实例在跑"而拒绝启动；新容器是全新 PID 命名空间，直接清理
rm -f "$PGDATA/postmaster.pid"

if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "[entrypoint] 初始化 PostgreSQL 数据目录..."
    /usr/lib/postgresql/15/bin/initdb -D "$PGDATA" -U postgres \
        --auth-local=trust --auth-host=trust -E UTF8 --locale=C
fi

echo "[entrypoint] 启动 supervisor 托管全部服务..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
