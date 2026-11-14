#!/bin/bash
# 一次性任务：等 PG 就绪 -> 建库 -> 跑 init.sql -> Alembic 迁移（逻辑来自原 start.sh）
set -e

PGREADY=""
for i in $(seq 1 60); do
    if pg_isready -h 127.0.0.1 -U postgres -p 5432 > /dev/null 2>&1; then
        PGREADY=1
        break
    fi
    echo "[dbinit] 等待 PostgreSQL... ($i/60)"
    sleep 2
done
[ -z "$PGREADY" ] && { echo "[dbinit] PostgreSQL 60次未就绪，退出"; exit 1; }
echo "[dbinit] PostgreSQL 已就绪"

# 建库（已存在则跳过）
psql -h 127.0.0.1 -U postgres -p 5432 -c "CREATE DATABASE gsk" 2>/dev/null \
    || echo "[dbinit] 数据库 gsk 已存在，跳过"

# 幂等建表（init.sql 全部 IF NOT EXISTS）
psql -h 127.0.0.1 -U postgres -p 5432 -d gsk -f /app/init.sql
echo "[dbinit] init.sql 执行完成"

# Alembic：首次打 baseline 标记，再升级到 head
cd /app
python - <<'EOF'
import os
from alembic.config import Config
from alembic import command
from sqlalchemy import create_engine, text

engine = create_engine(os.environ['DATABASE_URL'])
with engine.connect() as conn:
    result = conn.execute(text("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'alembic_version')"))
    table_exists = result.scalar()

alembic_cfg = Config('alembic.ini')
if not table_exists:
    print('[dbinit] 首次部署，标记 baseline 980b32f130df...')
    command.stamp(alembic_cfg, '980b32f130df')

print('[dbinit] 运行数据库迁移 upgrade head...')
command.upgrade(alembic_cfg, 'head')
print('[dbinit] 数据库迁移完成!')
EOF

echo "[dbinit] 数据库初始化全部完成"
exit 0
