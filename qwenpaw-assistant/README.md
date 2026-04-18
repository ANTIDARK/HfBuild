metadata

title: CoPaw
emoji: 🤖
colorFrom: blue
colorTo: purple
sdk: docker
app_port: 7860
pinned: false

公开 Space + 密码保护 → 保活不休眠
私有 Dataset 备份 → 防数据泄露
通过inotifywait监测文件变化实现实时备份

# 变量设置
## 必填
DATASET：私有dataset名称
HF_USERNAME：hf的用户名
HF_TOKEN：huggingface的具有write权限的token
AUTH_USER：网页登陆用户名
AUTH_PASSWORD：网页登陆密码
## 可选
DATA_DIR：qwenpaw数据文件位置
SECRET_DIR：qwenpaw使用的大模型密钥存储位置

