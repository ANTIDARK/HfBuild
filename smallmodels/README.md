metadata

title: Lightning Fast LLM API (2vCPU/16GB)
emoji: ⚡
colorFrom: blue
colorTo: purple
sdk: docker
pinned: false

Lightning Fast LLM API Service

专为 HuggingFace Spaces 免费版（2vCPU/16GB） 优化的极速大语言模型 API 服务，新增联网搜索功能，中文友好，纯CPU无压力。
🚀 核心特性

    💬 在线对话+联网搜索：开启开关即可回答实时问题，搜索结果自动拼接至prompt
    ⚡ 2vCPU极致优化：推理速度15-50+ tokens/秒，内存占用300MB-2GB
    🔧 中文友好模型库：精选8款适配2vCPU的轻量模型，支持一键切换
    🔒 API 认证保护：Bearer Token 验证，防止接口滥用
    📊 实时监控：显示当前模型、速度、内存占用、搜索状态
    🔧 全环境变量配置：所有参数支持环境变量覆盖，灵活定制

🔧 环境变量配置

在 Space Settings > Variables and Secrets 中设置，仅API_KEY为必填，其余均为2vCPU优化默认值：
变量名 	必填 	默认值 	说明（2vCPU专属）
API_KEY 	✅ 	- 	API 密钥（自定义，任意字符串）
OLLAMA_MODEL 	❌ 	llama3.2:1b 	启动模型（见下方推荐模型）
OLLAMA_CONTEXT_LENGTH 	❌ 	512 	上下文长度（2vCPU建议≤512）
OLLAMA_NUM_THREADS 	❌ 	2 	CPU线程数（强制匹配2vCPU）
SEARCH_ENABLE 	❌ 	true 	是否开启联网搜索功能
SEARCH_API_URL 	❌ 	轻量搜索接口 	自定义联网搜索接口（无跨域）
OLLAMA_KEEP_ALIVE 	❌ 	30m 	模型常驻内存时间（减少冷启动）
🚀 2vCPU 专属推荐模型

优先选择0.5B级模型，2vCPU无压力，中文首选qwen2.5:0.5b
模型 	内存占用 	推理速度 	核心优势 	适用场景
qwen2.5:0.5b 	300MB 	30-50 t/s 	中文最优，极致轻量 	中文对话/写作/问答
functiongemma 	270MB 	40-120 t/s 	速度最快，函数调用 	极速响应/简单函数调用
llama3.2:1b 	1.3GB 	18-30 t/s 	工具调用优秀，多语言 	综合对话/工具调用
chatglm4:1b 	1.2GB 	15-25 t/s 	中文深度优化，国内适配 	中文深度对话
📡 API 端点

    GET / - 在线对话界面（带联网搜索，无需认证）
    GET /health - 健康检查（无需认证，返回OK）
    POST /v1/chat/completions - 聊天补全（需Bearer Token认证，兼容OpenAI格式）

📝 API 调用示例

curl -X POST https://your-space.hf.space/v1/chat/completions \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:0.5b",
    "messages": [{"role": "user", "content": "2026年最新科技资讯"}],
    "temperature": 0.7
  }'
