#!/bin/bash
set -euo pipefail

# ===================== 安全配置 =====================
AUTH_USER="${AUTH_USER:-admin}"
AUTH_PASSWORD="${AUTH_PASSWORD:-SecurePass123}"

# HF 必传环境变量检查
if [ -z "${HF_USERNAME:-}" ] || [ -z "${HF_TOKEN:-}" ]; then
    echo "❌ 错误：必须设置 HF_USERNAME 和 HF_TOKEN 环境变量"
    exit 1
fi

HF_USERNAME="${HF_USERNAME}"
HF_TOKEN="${HF_TOKEN}"
DATA_DIR="/root/.qwenpaw"
SECRET_DIR="/root/.qwenpaw.secret"
DATASET="${DATASET:-qwenpaw-backup}"
DATASET_ID="${HF_USERNAME}/${DATASET}"
BACKUP_TIME="${BACKUP_TIME:-300}"

DIR1="${DATA_DIR}"
DIR2="${SECRET_DIR}"
# ====================================================

# 依赖检查
check_deps() {
    for cmd in python nginx htpasswd; do
        if ! command -v $cmd &>/dev/null; then
            echo "❌ 缺少依赖：$cmd，请先安装"
            exit 1
        fi
    done

    if ! python -c "import huggingface_hub" &>/dev/null; then
        echo "⚠️ 安装 huggingface_hub..."
        pip install huggingface_hub -q
    fi
}
check_deps

# 端口检查
check_ports() {
    for p in 8088 7860; do
        if lsof -i:$p -t >/dev/null 2>&1; then
            echo "❌ 端口 $p 被占用"
            exit 1
        fi
    done
}
check_ports

# ===================== 连通测试 =====================
test_connection() {
  echo -e "\n====================================="
  echo "🔒 私有 Dataset 连通性测试"
  echo "====================================="
  python -c "
from huggingface_hub import HfApi
api = HfApi()
try:
    api.repo_info(token='${HF_TOKEN}', repo_id='${DATASET_ID}', repo_type='dataset')
    print('✅ 连接成功')
except Exception as e:
    print('❌ 连接失败：', e)
    exit(1)
"
  echo "=====================================\n"
}
test_connection


# ========== 拉取备份 ==========
pull_all_backup() {
    BACKUP_ROOT="/root/hf_backup_tmp"
    [ -d "${BACKUP_ROOT}" ] && rm -rf "${BACKUP_ROOT}"
    mkdir -p "${BACKUP_ROOT}"

    echo "ℹ️ 拉取备份..."
    python -c "
from huggingface_hub import snapshot_download
try:
    snapshot_download(
        repo_id='${DATASET_ID}',
        repo_type='dataset',
        local_dir='${BACKUP_ROOT}',
        token='${HF_TOKEN}',
        resume_download=True
    )
except:
    pass
"


    if [ -d "${BACKUP_ROOT}/.qwenpaw" ]; then
        rm -rf "${DIR1}"
        mv "${BACKUP_ROOT}/.qwenpaw" /root/
        echo "✅ 恢复 ${DIR1}"
    fi

    if [ -d "${BACKUP_ROOT}/.qwenpaw.secret" ]; then
        rm -rf "${DIR2}"
        mv "${BACKUP_ROOT}/.qwenpaw.secret" /root/
        echo "✅ 恢复 ${DIR2}"
    fi

    rm -rf "${BACKUP_ROOT}"
}
pull_all_backup

# ========== 【实时同步】文件一改动就自动上传 ==========
# ========== 【修复版】文件实时同步 ==========
auto_double_backup() {
    # 安装依赖
    if ! command -v inotifywait &>/dev/null; then
        apt update && apt install -y inotify-tools -y
    fi

    echo "✅ 实时同步已启动 → 监听：$DIR1 $DIR2"
    echo "✅ 文件一旦修改，自动同步到云端"

    # 首次同步
    sync_files

    # 无限循环监听（去掉 -m，正常触发）
    while true; do
        # 关键：去掉 -m，一次事件就退出，才能执行同步
        inotifywait -e create,delete,modify,move -r "$DIR1" "$DIR2" 2>/dev/null
        echo "🔄 检测到文件变化，开始同步..."
        sync_files
    done
}

# 同步函数（不变）
sync_files() {
    SYNC_TMP="/root/sync_tmp"
    mkdir -p "$SYNC_TMP"

    # 增量拉取云端最新
    python -c "
from huggingface_hub import snapshot_download
try:
    snapshot_download(
        repo_id='${DATASET_ID}',
        repo_type='dataset',
        local_dir='${SYNC_TMP}',
        token='${HF_TOKEN}',
        resume_download=True
    )
except:
    pass
"

    # 覆盖本地变更
    [ -d "$DIR1" ] && cp -rf "$DIR1" "$SYNC_TMP"/
    [ -d "$DIR2" ] && cp -rf "$DIR2" "$SYNC_TMP"/

    # 增量上传
    python -c "
from huggingface_hub import HfApi
try:
    api = HfApi()
    api.upload_folder(
        folder_path='${SYNC_TMP}',
        repo_id='${DATASET_ID}',
        repo_type='dataset',
        token='${HF_TOKEN}'
    )
except Exception as e:
    print('同步失败：', e)
"

    rm -rf "$SYNC_TMP"
    echo "✅ $(date '+%Y-%m-%d %H:%M:%S') 同步完成"
}
auto_double_backup &

# ===================== Nginx =====================
htpasswd -cb /etc/nginx/.htpasswd "${AUTH_USER}" "${AUTH_PASSWORD}"

# 备份原有配置
[ -f /etc/nginx/sites-enabled/default ] && \
cp /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.bak.$(date +%s)

cat > /etc/nginx/sites-enabled/default << EOF
server {
    listen 7860;
    auth_basic "Private qwenpaw";
    auth_basic_user_file /etc/nginx/.htpasswd;
    location / {
        proxy_pass http://127.0.0.1:8088/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# ===================== 启动应用 =====================
echo 当前时间：$(date '+%Y年%m月%d日 %H:%M:%S 星期%w')
echo "ℹ️ 启动 qwenpaw..."
qwenpaw app --host 127.0.0.1 --port 8088 &
sleep 3

# 等待所有后台进程 + 前台 Nginx
wait &
nginx -g "daemon off;"