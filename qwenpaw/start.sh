#!/bin/bash
set -euo pipefail

# ===================== 防重复执行锁 =====================
LOCK_FILE="/tmp/qwenpaw_start.lock"
if [ -f "${LOCK_FILE}" ]; then
    echo "⚠️  检测到脚本已在运行，跳过重复启动"
    exit 0
fi
touch "${LOCK_FILE}"
trap "rm -f ${LOCK_FILE}" EXIT

# ===================== 配置（可通过环境变量覆盖）=====================
# HF 配置（必须在Space环境变量里设置）
HF_USERNAME="${HF_USERNAME}"
HF_TOKEN="${HF_TOKEN}"
DATASET="${DATASET:-qwenpaw-backup}"
DATASET_ID="${HF_USERNAME}/${DATASET}"
DATASET_BRANCH="${DATASET_BRANCH:-main}"
# 备份目录
QWENPAW_WORKING_DIR="${QWENPAW_WORKING_DIR:-"/root/.qwenpaw"}"
QWENPAW_SECRET_DIR="${QWENPAW_SECRET_DIR:-"/root/.qwenpaw.secret"}"
DIR1="${QWENPAW_WORKING_DIR}"
DIR2="${QWENPAW_SECRET_DIR}"
# 备份配置
BACKUP_MODE="${BACKUP_MODE:-timed}"
BACKUP_HISTORY_LIMIT="${BACKUP_HISTORY_LIMIT:-3}"
BACKUP_INTERVAL="${BACKUP_INTERVAL:-600}"
REALTIME_DEBOUNCE="${REALTIME_DEBOUNCE:-2}"
# 启用web认证
QWENPAW_AUTH_ENABLED="${QWENPAW_AUTH_ENABLED:-true}"
QWENPAW_AUTH_USERNAME="${QWENPAW_AUTH_USERNAME:-root}"
QWENPAW_AUTH_PASSWORD="${QWENPAW_AUTH_PASSWORD:-rootroot}"

# ================================================
# 首次初始化配置qwenpaw
#qwenpaw init --defaults
#sleep 2

# ================================================
# 前置校验
if [ -z "${HF_USERNAME}" ] || [ -z "${HF_TOKEN}" ]; then
    echo "❌ 致命错误：必须设置 HF_USERNAME 和 HF_TOKEN 环境变量"
    exit 1
fi
if [ "${BACKUP_HISTORY_LIMIT}" -lt 1 ]; then
    echo "❌ 致命错误：BACKUP_HISTORY_LIMIT 必须大于等于1"
    exit 1
fi

# 目录创建
mkdir -p "${DIR1}" "${DIR2}"
TMP_ROOT="/tmp/qwenpaw_backup"
rm -rf "${TMP_ROOT}" && mkdir -p "${TMP_ROOT}"

# ==================== 安全打包（无tar警告） ====================
make_clean_archive() {
  local archive="${1:-}"
  if [ -z "${archive}" ]; then
    echo "❌ 打包错误：未指定归档文件"
    return 1
  fi

  rm -f "${archive}"

  # 生成临时排除文件
  local exclude_file="${TMP_ROOT}/exclude.txt"
  cat > "${exclude_file}" << 'EOF'
logs
*.log
tmp
temp
cache
__pycache__
*.pyc
*.pyo
.git
.gitignore
.lock
*.lock
EOF

  cd /root
  tar -zcf "${archive}" --ignore-failed-read \
    --exclude-from="${exclude_file}" \
    .qwenpaw .qwenpaw.secret 2>/dev/null || true

  rm -f "${exclude_file}"
}

# ==================== 空Dataset判断（不卡死） ====================
pull_latest_backup() {
  # 快速检查Dataset是否有备份文件
  local has_backup="NO"
  has_backup=$(python3 -c "
from huggingface_hub import HfApi
api = HfApi(token='${HF_TOKEN}')
try:
    files = api.list_repo_files(repo_id='${DATASET_ID}', repo_type='dataset', revision='${DATASET_BRANCH}')
    for f in files:
        if f.startswith('qwenpaw_backup_') and f.endswith('.tar.gz'):
            print('YES')
            exit(0)
    print('NO')
except Exception as e:
    print('NO')
" 2>/dev/null || echo "NO")

  if [ "${has_backup}" != "YES" ]; then
    echo "ℹ️ Dataset为空，跳过恢复"
    return
  fi

  # 有备份才下载恢复
  echo "📥 发现备份，开始恢复..."
  local tmp_dir="/tmp/restore"
  rm -rf "${tmp_dir}" && mkdir -p "${tmp_dir}"

  python3 -c "
from huggingface_hub import snapshot_download
try:
    snapshot_download(
        repo_id='${DATASET_ID}',
        repo_type='dataset',
        revision='${DATASET_BRANCH}',
        local_dir='${tmp_dir}',
        token='${HF_TOKEN}',
        allow_patterns=['qwenpaw_backup_*.tar.gz'],
        force_download=True,
        max_workers=1
    )
except Exception as e:
    pass
" 2>&1 | head -10 || true

  # 解压
  latest=$(ls -t ${tmp_dir}/qwenpaw_backup_*.tar.gz 2>/dev/null | head -1 || true)
  if [ -n "${latest:-}" ] && [ -f "${latest}" ]; then
    cd /root
    tar -zxf "${latest}" -C /root/ 2>/dev/null || true
    echo "✅ 配置恢复成功"
  fi
  rm -rf "${tmp_dir}"
}

# ==================== 上传+历史清理（修正API参数名） ====================
upload_and_purge_history() {
  local archive="${1:-}"
  if [ -z "${archive}" ] || [ ! -f "${archive}" ]; then
    echo "❌ 上传错误：归档文件不存在"
    return 1
  fi

  local filename="$(basename "${archive}")"

  # 环境变量传递
  export HF_TOKEN
  export DATASET_ID
  export DATASET_BRANCH
  export BACKUP_HISTORY_LIMIT
  export ARCHIVE="${archive}"
  export FILENAME="${filename}"

  # Python清理逻辑：全链路日志+异常暴露+兼容旧文件+修正delete_file参数名为path_in_repo
  python3 << 'EOF'
import os
import sys
from huggingface_hub import HfApi

# 环境变量校验
required_env = ['HF_TOKEN', 'DATASET_ID', 'DATASET_BRANCH', 'BACKUP_HISTORY_LIMIT', 'ARCHIVE', 'FILENAME']
for env in required_env:
    if env not in os.environ or not os.environ[env]:
        print(f"❌ 环境变量缺失：{env}")
        sys.exit(1)

api = HfApi(token=os.environ['HF_TOKEN'])
repo_id = os.environ['DATASET_ID']
revision = os.environ['DATASET_BRANCH']
keep = int(os.environ['BACKUP_HISTORY_LIMIT'])
archive = os.environ['ARCHIVE']
filename = os.environ['FILENAME']

# 上传新备份（带日志）
print(f"\n📤 开始上传备份：{filename}")
try:
    api.upload_file(
        path_or_fileobj=archive,
        path_in_repo=filename,
        repo_id=repo_id,
        repo_type='dataset',
        revision=revision
    )
    print(f"✅ 上传成功：{filename}")
except Exception as e:
    print(f"❌ 上传失败：{str(e)}")
    sys.exit(1)

# 获取备份文件
print(f"\n📦 获取仓库备份文件列表...")
try:
    all_files = api.list_repo_files(repo_id=repo_id, repo_type='dataset', revision=revision)
except Exception as e:
    print(f"❌ 获取文件列表失败：{str(e)}")
    sys.exit(1)

# 过滤备份文件
backup_files = []
for f in all_files:
    if f.startswith('qwenpaw_backup_') and f.endswith('.tar.gz'):
        backup_files.append(f)

if not backup_files:
    print("ℹ️ 仓库中无匹配的备份文件，无需清理")
    sys.exit(0)

# 强制按时间戳降序排序（新文件在前）
backup_files.sort(reverse=True)
print(f"✅ 找到备份文件：共{len(backup_files)}个")
print(f"📋 排序后列表：{backup_files}")
print(f"🔢 保留最新{keep}个，删除剩余{len(backup_files)-keep}个")

# 删除超量旧备份（暴露异常，不静默跳过）
# 优化：防限流分批删除】
# 单次最多删5个，防高频限流
MAX_DELETE_PER_TIME = 5
# 每删一个休眠1秒
DELETE_SLEEP_SEC = 1

if len(backup_files) > keep:
    to_delete = backup_files[keep:]
    # 限制单次最多删MAX_DELETE_PER_TIME个
    to_delete = to_delete[:MAX_DELETE_PER_TIME]

    print(f"⚠️  本次分批清理，最多删除 {MAX_DELETE_PER_TIME} 个旧备份")
    for idx, f in enumerate(to_delete):
        try:
            print(f"🗑️  [{idx+1}] 正在删除：{f}")
            api.delete_file(
                path_in_repo=f,
                repo_id=repo_id,
                repo_type='dataset',
                revision=revision
            )
            print(f"✅ 删除成功：{f}")
            # 每删一个休眠，降频防限流
            import time
            time.sleep(DELETE_SLEEP_SEC)
        except Exception as e:
            err_msg = str(e).lower()
            # 遇到429限流直接终止本次删除，下次备份再清
            if "429" in err_msg or "too many requests" in err_msg:
                print("❌ 触发HF API限流，停止本次清理，下次备份自动继续")
                break
            print(f"❌ 删除失败：{f}，原因：{str(e)}")
else:
    print(f"ℹ️ 当前备份数量未超过限制，无需清理")

print(f"\n✅ 备份+清理流程全部完成")
EOF
}

# ==================== 备份执行 ====================
do_backup() {
  local ts=$(date +%Y%m%d_%H%M%S)
  local archive="${TMP_ROOT}/qwenpaw_backup_${ts}.tar.gz"

  make_clean_archive "${archive}"

  if [ -f "${archive}" ]; then
    upload_and_purge_history "${archive}"
    rm -f "${archive}"
    echo "✅ [${ts}] 备份完成"
  fi
}

# ==================== 启动流程 ====================
echo "====================================="
echo "🔒 备份模式：${BACKUP_MODE}"
echo "📦 保留历史：${BACKUP_HISTORY_LIMIT}"
echo "====================================="

# 检查Dataset
python3 -c "
from huggingface_hub import HfApi
api = HfApi(token='${HF_TOKEN}')
try:
    api.repo_info(repo_id='${DATASET_ID}', repo_type='dataset', revision='${DATASET_BRANCH}')
    print('✅ Dataset 连接正常')
except:
    print('❌ Dataset 连接失败')
" 2>/dev/null || true

# 执行恢复
pull_latest_backup

# 启动备份任务
if [ "${BACKUP_MODE}" = "realtime" ]; then
  echo "⏱️  实时备份已启动"
  (
    while true; do
      inotifywait -r -q -e create,delete,modify,move \
        --exclude 'log|lock|tmp' "${DIR1}" "${DIR2}" 2>/dev/null || true
      sleep ${REALTIME_DEBOUNCE}
      do_backup
    done
  ) &
else
  echo "⏱️  定时备份：${BACKUP_INTERVAL} 秒"
  (
    while true; do
      sleep ${BACKUP_INTERVAL}
      do_backup
    done
  ) &
fi


# ==================== 启动QwenPaw ====================
echo "🚀 启动 QwenPaw..."
exec qwenpaw app --host 0.0.0.0 --port 7860 --log-level WARNING
