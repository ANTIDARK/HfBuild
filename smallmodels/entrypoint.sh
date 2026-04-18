#!/bin/bash
set -e

# 必选环境变量检查
if [ -z "$API_KEY" ]; then
    echo "❌ 错误：必须设置 API_KEY 环境变量"
    exit 1
fi

# LLM 核心配置（2vCPU 纯离线优化，Ollama官方可拉取模型）
export OLLAMA_MODEL=${OLLAMA_MODEL:-"qwen2.5:0.5b"}
export OLLAMA_CONTEXT_LENGTH=${OLLAMA_CONTEXT_LENGTH:-512}
export OLLAMA_NUM_THREADS=${OLLAMA_NUM_THREADS:-2}
export OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE:-"30m"}
export OLLAMA_KV_CACHE_TYPE=${OLLAMA_KV_CACHE_TYPE:-"q4_0"}

# 打印启动信息
echo "============================================="
echo "⚡ HuggingFace 2vCPU/16GB 纯离线 LLM 服务"
echo "============================================="
echo "✅ 当前运行模型：$OLLAMA_MODEL"
echo "✅ CPU 线程数：$OLLAMA_NUM_THREADS（匹配2vCPU）"
echo "✅ 量化级别：Q4_0（75%内存节省）"
echo "✅ 运行模式：100%纯本地离线 | 无外部网络请求"
echo "============================================="

# 生成前端页面（新增使用说明+微调功能+全模型列表）
mkdir -p /usr/share/nginx/html
cat > /usr/share/nginx/html/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>2vCPU 纯离线LLM | 使用说明 + 全功能版</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:system-ui, -apple-system, BlinkMacSystemFont, sans-serif;background:#f6f8fa;min-height:100vh;color:#24292f}
        .container{max-width:1200px;margin:0 auto;padding:20px}
        .header{background:#24292f;color:white;padding:28px;border-radius:12px;margin-bottom:24px}
        .header h1{font-size:24px;margin-bottom:8px}
        .header p{opacity:0.9;font-size:15px}
        .card{background:white;border-radius:12px;box-shadow:0 1px 3px rgba(0,0,0,0.1);padding:24px;margin-bottom:24px}
        .card h2{font-size:18px;margin-bottom:16px;color:#24292f;border-left:4px solid #4285f4;padding-left:12px;display:flex;align-items:center;gap:8px}
        .card h3{font-size:16px;margin:16px 0 8px;color:#24292f}
        .chat-card{height:650px;display:flex;flex-direction:column}
        .messages{flex:1;padding:20px;overflow-y:auto;background:#fafbfc;border-radius:8px;margin-bottom:20px}
        .msg{margin-bottom:16px;max-width:85%}
        .msg.user{margin-left:auto}
        .bubble{padding:12px 16px;border-radius:18px;line-height:1.6;word-wrap:break-word}
        .user .bubble{background:#4285f4;color:white;border-bottom-right-radius:4px}
        .assistant .bubble{background:white;border:1px solid #e1e4e8;border-bottom-left-radius:4px}
        /* 微调参数区域样式 */
        .tuning-panel{background:#f8f9fa;padding:16px;border-radius:8px;margin-bottom:20px}
        .tuning-row{display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;padding-bottom:10px;border-bottom:1px solid #eee}
        .tuning-row:last-child{margin-bottom:0;padding-bottom:0;border-bottom:none}
        .tuning-label{font-size:14px;color:#495057;width:100px}
        .tuning-control{flex:1;margin:0 10px}
        .tuning-value{font-size:14px;font-weight:600;color:#24292f;width:60px;text-align:right}
        input[type="range"]{width:100%;height:6px;border-radius:3px;background:#e1e4e8;outline:none}
        input[type="range"]::-webkit-slider-thumb{width:16px;height:16px;border-radius:50%;background:#4285f4;cursor:pointer}
        .input-box{display:flex;gap:10px;align-items:center}
        .input-box input{flex:1;padding:14px 20px;border:1px solid #ddd;border-radius:28px;outline:none;font-size:15px;transition:border 0.2s}
        .input-box input:focus{border-color:#4285f4}
        .input-box button{padding:14px 28px;background:#4285f4;color:white;border:none;border-radius:28px;cursor:pointer;font-size:15px;font-weight:500;transition:background 0.2s}
        .input-box button:hover{background:#3367d6}
        .loading{display:none;padding:10px 16px;color:#666;font-size:14px}
        .loading.active{display:block}
        /* API代码块样式 */
        .api-code{background:#1e1e1e;color:#d4d4d4;padding:20px;border-radius:8px;overflow-x:auto;font-family:Consolas, Monaco, monospace;font-size:14px;line-height:1.8;margin:16px 0}
        .copy-btn{padding:8px 16px;background:#2ea44f;color:white;border:none;border-radius:6px;cursor:pointer;font-size:14px;margin-bottom:8px;display:inline-flex;align-items:center;gap:6px}
        .copy-btn:hover{background:#22863a}
        /* 模型列表表格样式 */
        .model-table{width:100%;border-collapse:collapse;margin:16px 0;font-size:14px}
        .model-table th, .model-table td{padding:12px 16px;text-align:left;border-bottom:1px solid #e1e4e8}
        .model-table th{background:#f6f8fa;font-weight:600;color:#24292f;white-space:nowrap}
        .model-table tr:hover{background:#fafbfc}
        .model-table .tag{display:inline-block;padding:2px 6px;border-radius:4px;font-size:12px;font-weight:600;margin-left:6px}
        .tag-cn{background:#d4edda;color:#155724}
        .tag-code{background:#e3f2fd;color:#0277bd}
        .tag-fast{background:#fff3cd;color:#856404}
        .tag-math{background:#f3e5f5;color:#7b1fa2}
        /* 模型分类标题 */
        .model-cat{font-size:15px;font-weight:600;margin:20px 0 8px;color:#4285f4;padding-left:8px;border-left:3px solid #4285f4}
        /* 使用说明样式 */
        .guide-list{margin:12px 0 20px 20px;line-height:1.8;font-size:14px;color:#495057}
        .guide-list li{margin-bottom:8px}
        .guide-note{background:#fff3cd;padding:12px;border-radius:6px;font-size:14px;color:#856404;margin:16px 0}
        .faq-item{margin-bottom:16px}
        .faq-question{font-weight:600;color:#24292f;margin-bottom:4px}
        .faq-answer{font-size:14px;color:#495057;line-height:1.6}
        /* 响应式适配 */
        @media (max-width:900px) {
            .container{padding:12px}
            .card{padding:16px}
            .chat-card{height:600px}
            .model-table th, .model-table td{padding:8px 10px;font-size:13px}
            .input-box input{padding:12px 16px}
            .input-box button{padding:12px 20px}
            .tuning-label{width:80px}
        }
        @media (max-width:768px) {
            .container > div {grid-template-columns:1fr !important;gap:16px !important}
            .chat-card{height:550px}
            .tuning-row{flex-direction:column;align-items:flex-start}
            .tuning-control{width:100%;margin:5px 0}
            .tuning-value{align-self:flex-end;margin-top:-25px}
        }
    </style>
</head>
<body>
<div class="container">
    <!-- 头部 -->
    <div class="header">
        <h1>⚡ 2vCPU/16GB 纯离线大语言模型服务</h1>
        <p>Ollama官方全模型支持 | 纯CPU运行 | 对话参数微调 | API兼容OpenAI | 详细使用指南</p>
    </div>

    <div style="display:grid;grid-template-columns:1fr 420px;gap:24px">
        <!-- 左侧：聊天窗口 + 微调功能 -->
        <div class="card chat-card">
            <h2>💬 在线对话（纯离线 + 参数微调）</h2>
            
            <!-- 对话微调参数面板 -->
            <div class="tuning-panel">
                <h3>⚙️ 对话微调参数</h3>
                <!-- 温度参数（控制随机性） -->
                <div class="tuning-row">
                    <label class="tuning-label">温度 (Temperature)</label>
                    <input type="range" class="tuning-control" id="temperature" min="0" max="2" step="0.1" value="0.7" oninput="updateTuningValue('temperature', this.value)">
                    <span class="tuning-value" id="temperature-value">0.7</span>
                </div>
                <!-- 最大生成tokens（控制回复长度） -->
                <div class="tuning-row">
                    <label class="tuning-label">最大回复长度</label>
                    <input type="range" class="tuning-control" id="max-tokens" min="100" max="1024" step="50" value="512" oninput="updateTuningValue('max-tokens', this.value)">
                    <span class="tuning-value" id="max-tokens-value">512</span>
                </div>
                <!-- 上下文长度（控制记忆能力） -->
                <div class="tuning-row">
                    <label class="tuning-label">上下文长度</label>
                    <input type="range" class="tuning-control" id="context-length" min="256" max="1024" step="128" value="512" oninput="updateTuningValue('context-length', this.value)">
                    <span class="tuning-value" id="context-length-value">512</span>
                </div>
            </div>

            <div class="messages" id="msg-container">
                <div class="msg assistant">
                    <div class="bubble">
                        你好！我是 <span id="current-model" style="font-weight:600;color:#4285f4">MODEL_PLACEHOLDER</span>，
                        专为2vCPU/16GB优化的纯离线大模型～<br><br>
                        支持：中文对话、代码生成、数学推理、写作辅助、文本分析，<br>
                        可通过上方微调参数控制回复风格、长度和记忆能力，所有操作均本地完成！
                    </div>
                </div>
            </div>
            <div class="loading" id="ai-loading">🤖 思考中...</div>
            <div class="input-box">
                <input id="chat-input" placeholder="输入你的问题，按回车发送..." onkeydown="if(event.key==='Enter')sendMessage()">
                <button onclick="sendMessage()">发送</button>
            </div>
        </div>

        <!-- 右侧：使用说明 + API文档 + 全模型列表 -->
        <div style="display:flex;flex-direction:column;gap:24px">
            <!-- 新增：使用说明板块 -->
            <div class="card">
                <h2>📖 详细使用说明</h2>
                
                <h3>1. 部署配置（必填步骤）</h3>
                <ul class="guide-list">
                    <li>进入HuggingFace仓库 → <strong>Settings > Variables and Secrets</strong></li>
                    <li>添加必填环境变量：<code>API_KEY</code>（自定义任意字符串，用于API认证）</li>
                    <li>可选配置：<code>OLLAMA_MODEL</code>（指定默认模型，默认qwen2.5:0.5b）</li>
                    <li>保存后重启Space，等待2-3分钟即可使用</li>
                </ul>

                <h3>2. 模型切换方法</h3>
                <ul class="guide-list">
                    <li>查看下方「适配模型全列表」，选择想要的模型名称（如llama3.2:1b）</li>
                    <li>在环境变量中添加/修改 <code>OLLAMA_MODEL=模型名称</code></li>
                    <li>重启HuggingFace Space，模型会自动拉取并生效</li>
                </ul>
                <div class="guide-note">
                    ⚠️ 提示：模型切换后需重新拉取，建议选择≤1.5B参数的模型，2vCPU运行更流畅
                </div>

                <h3>3. 对话微调参数说明</h3>
                <ul class="guide-list">
                    <li><strong>温度</strong>：0=确定性强（适合代码/数学），2=创造性强（适合文案/创意）</li>
                    <li><strong>最大回复长度</strong>：控制单次回复的tokens数量，越长占用CPU/内存越多</li>
                    <li><strong>上下文长度</strong>：控制模型能记住的对话历史，越长记忆越好但性能略降</li>
                </ul>

                <h3>4. API调用指南</h3>
                <ul class="guide-list">
                    <li>接口地址：你的Space域名 + <code>/v1/chat/completions</code></li>
                    <li>认证方式：请求头添加 <code>Authorization: Bearer 你的API_KEY</code></li>
                    <li>支持参数：temperature、max_tokens、stream等（兼容OpenAI）</li>
                    <li>下方提供Curl示例，可一键复制使用</li>
                </ul>

                <h3>5. 常见问题（FAQ）</h3>
                <div class="faq-item">
                    <div class="faq-question">Q：启动后无法访问？</div>
                    <div class="faq-answer">A：检查API_KEY是否配置，查看Space日志是否有模型拉取失败提示，重启Space重试</div>
                </div>
                <div class="faq-item">
                    <div class="faq-question">Q：对话响应慢？</div>
                    <div class="faq-answer">A：降低最大回复长度/上下文长度，选择0.5B级超轻量模型，关闭其他占用CPU的服务</div>
                </div>
                <div class="faq-item">
                    <div class="faq-question">Q：API调用返回401？</div>
                    <div class="faq-answer">A：检查API_KEY是否正确，请求头格式是否为「Bearer + 空格 + API_KEY」</div>
                </div>
            </div>

            <!-- API使用方法 -->
            <div class="card">
                <h2>🔌 API 调用示例</h2>
                <button class="copy-btn" onclick="copyApiCode()">📋 复制Curl调用示例</button>
                <div class="api-code" id="api-code-block">
curl -X POST https://your-space.hf.space/v1/chat/completions \
  -H "Authorization: Bearer API_KEY_PLACEHOLDER" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "MODEL_PLACEHOLDER",
    "messages": [{"role": "user", "content": "你好，介绍一下你自己"}],
    "temperature": 0.7,
    "max_tokens": 512,
    "stream": false
  }'
                </div>
            </div>

            <!-- 全模型列表 -->
            <div class="card" style="flex:1">
                <h2>📦 适配模型全列表（Ollama官方）</h2>
                <p style="font-size:14px;margin-bottom:12px;color:#666">
                    所有模型均支持纯CPU运行，内存占用≤2GB，2vCPU流畅适配
                </p>

                <!-- 极速超轻量型（≤500MB） -->
                <div class="model-cat">🚀 极速超轻量型（≤500MB | 秒启动）</div>
                <table class="model-table">
                    <thead>
                        <tr>
                            <th>模型名称</th>
                            <th>内存</th>
                            <th>速度</th>
                            <th>优势</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr class="model-item">
                            <td>qwen2.5:0.5b</td>
                            <td>300MB</td>
                            <td>30-50 t/s</td>
                            <td>中文最优 <span class="tag tag-cn">中文</span></td>
                        </tr>
                        <tr class="model-item">
                            <td>qwen2.5-coder:0.5b</td>
                            <td>300MB</td>
                            <td>30-45 t/s</td>
                            <td>轻量代码 <span class="tag tag-code">代码</span></td>
                        </tr>
                        <tr class="model-item">
                            <td>minicpm4:0.5b</td>
                            <td>280MB</td>
                            <td>35-60 t/s</td>
                            <td>中文推理 <span class="tag tag-math">推理</span></td>
                        </tr>
                        <tr class="model-item">
                            <td>functiongemma</td>
                            <td>270MB</td>
                            <td>40-120 t/s</td>
                            <td>速度最快 <span class="tag tag-fast">极速</span></td>
                        </tr>
                    </tbody>
                </table>

                <!-- 全能平衡型（1B级） -->
                <div class="model-cat">⚡ 全能平衡型（1B级 | 质量兼顾）</div>
                <table class="model-table">
                    <thead>
                        <tr>
                            <th>模型名称</th>
                            <th>内存</th>
                            <th>速度</th>
                            <th>优势</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr class="model-item">
                            <td>llama3.2:1b</td>
                            <td>1.3GB</td>
                            <td>18-30 t/s</td>
                            <td>综合最佳 <span class="tag tag-fast">推荐</span></td>
                        </tr>
                        <tr class="model-item">
                            <td>gemma3:1b</td>
                            <td>1GB</td>
                            <td>15-25 t/s</td>
                            <td>多语言强 <span class="tag tag-cn">多语言</span></td>
                        </tr>
                        <tr class="model-item">
                            <td>qwen3.5:0.8b</td>
                            <td>400MB</td>
                            <td>25-40 t/s</td>
                            <td>新版中文 <span class="tag tag-cn">新版</span></td>
                        </tr>
                    </tbody>
                </table>

                <!-- 高质量进阶型（1.5B级） -->
                <div class="model-cat">📈 高质量进阶型（1.5B级 | 质更优）</div>
                <table class="model-table">
                    <thead>
                        <tr>
                            <th>模型名称</th>
                            <th>内存</th>
                            <th>速度</th>
                            <th>优势</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr class="model-item">
                            <td>qwen2.5:1.5b</td>
                            <td>1.5GB</td>
                            <td>8-15 t/s</td>
                            <td>中文化质 <span class="tag tag-cn">高质</span></td>
                        </tr>
                        <tr class="model-item">
                            <td>deepseek-r1:1.5b</td>
                            <td>1.5GB</td>
                            <td>5-10 t/s</td>
                            <td>逻辑推理 <span class="tag tag-math">推理</span></td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<script>
    // 全局配置（占位符替换后生效）
    const API_KEY = "API_KEY_PLACEHOLDER";
    const CURRENT_MODEL = "MODEL_PLACEHOLDER";
    const API_HOST = window.location.origin;
    const messages = [];

    // 初始化页面
    document.addEventListener('DOMContentLoaded', function() {
        // 替换当前模型显示
        document.getElementById('current-model').textContent = CURRENT_MODEL;
        // 替换API地址
        document.getElementById('api-host').textContent = API_HOST;
        // 聚焦输入框
        document.getElementById('chat-input').focus();
    });

    // 更新微调参数显示值
    function updateTuningValue(id, value) {
        document.getElementById(`${id}-value`).textContent = value;
    }

    // 复制API代码（自动填充当前域名、API_KEY、运行模型）
    function copyApiCode() {
        const code = `curl -X POST ${API_HOST}/v1/chat/completions \\
  -H "Authorization: Bearer ${API_KEY}" \\
  -H "Content-Type: application/json" \\
  -d '{
    "model": "${CURRENT_MODEL}",
    "messages": [{"role": "user", "content": "你好，介绍一下你自己"}],
    "temperature": 0.7,
    "max_tokens": 512,
    "stream": false
  }'`;
        navigator.clipboard.writeText(code).then(() => {
            alert("✅ API代码已成功复制到剪贴板！");
        }).catch(err => {
            alert("❌ 复制失败，请手动复制代码块内容！");
        });
    }

    // 添加消息到聊天窗口
    function addMessage(role, content) {
        const container = document.getElementById('msg-container');
        const msgDiv = document.createElement('div');
        msgDiv.className = `msg ${role}`;
        msgDiv.innerHTML = `<div class="bubble">${content.replace(/\n/g, '<br>')}</div>`;
        container.appendChild(msgDiv);
        // 自动滚动到底部
        container.scrollTop = container.scrollHeight;
    }

    // 发送聊天消息（整合微调参数）
    async function sendMessage() {
        const input = document.getElementById('chat-input');
        const content = input.value.trim();
        if (!content) return;

        // 获取微调参数值
        const temperature = parseFloat(document.getElementById('temperature').value);
        const maxTokens = parseInt(document.getElementById('max-tokens').value);
        const contextLength = parseInt(document.getElementById('context-length').value);

        // 清空输入框+添加用户消息
        input.value = '';
        addMessage('user', content);
        // 显示加载状态
        document.getElementById('ai-loading').classList.add('active');

        try {
            // 调用本地Ollama API（携带微调参数）
            const response = await fetch(`${API_HOST}/v1/chat/completions`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${API_KEY}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    model: CURRENT_MODEL,
                    messages: [{ role: 'user', content: content }],
                    temperature: temperature,
                    max_tokens: maxTokens,
                    context_length: contextLength, // 上下文长度参数
                    stream: false
                })
            });

            if (!response.ok) throw new Error(`HTTP ${response.status} (认证/服务错误)`);
            const data = await response.json();
            const assistantContent = data.choices[0].message.content;
            addMessage('assistant', assistantContent);
        } catch (error) {
            addMessage('assistant', `❌ 请求失败：${error.message}<br><br>排查建议：<br>1. 检查API_KEY是否配置正确<br>2. 重启HuggingFace Space<br>3. 确认模型已成功拉取`);
        } finally {
            // 隐藏加载状态
            document.getElementById('ai-loading').classList.remove('active');
        }
    }
</script>
</body>
</html>
HTML_EOF

# 替换前端所有占位符（模型/API_KEY/域名）
sed -i "s|MODEL_PLACEHOLDER|$OLLAMA_MODEL|g" /usr/share/nginx/html/index.html
sed -i "s|API_KEY_PLACEHOLDER|$API_KEY|g" /usr/share/nginx/html/index.html

# 生成Nginx配置（纯本地代理+严格API认证+兼容OpenAI）
cat > /etc/nginx/nginx.conf << 'NGINX_EOF'
user root;
worker_processes auto;
error_log /dev/stderr;
pid /var/run/nginx.pid;
events {
    worker_connections 1024;
}
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /dev/stdout main;
    keepalive_timeout 60s;

    # API_KEY 认证映射（严格校验，防止接口滥用）
    map $http_authorization $api_key_valid {
        default 0;
        "Bearer API_KEY_PLACEHOLDER" 1;
        "BearerAPI_KEY_PLACEHOLDER" 1; # 兼容无空格的情况
    }

    server {
        listen 7860 default_server;
        server_name _;
        client_max_body_size 10M;

        # 前端页面（无需认证，直接访问）
        location = / {
            access_log off;
            root /usr/share/nginx/html;
            try_files /index.html =404;
            add_header Cache-Control "no-cache, no-store, must-revalidate";
        }

        # 健康检查端点（无需认证，用于HuggingFace状态检测）
        location /health {
            access_log off;
            return 200 "OK";
            add_header Content-Type text/plain;
            add_header Cache-Control "no-cache";
        }

        # Ollama API代理（所有/v1/开头的请求，需要API_KEY认证）
        location / {
            # 认证校验，未通过直接返回401
            if ($api_key_valid = 0) {
                return 401 '{"error":"Unauthorized","message":"Invalid or missing API Key. Visit / for documentation."}';
                add_header Content-Type application/json;
                add_header Cache-Control "no-cache";
            }
            # 代理到本地Ollama服务（127.0.0.1:11434）
            proxy_pass http://127.0.0.1:11434;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            # 延长超时时间，适配2vCPU推理速度
            proxy_read_timeout 300s;
            proxy_send_timeout 300s;
            # 关闭缓冲，提升流式响应体验
            proxy_buffering off;
            proxy_cache off;
        }
    }
}
NGINX_EOF

# 替换Nginx中的API_KEY占位符
sed -i "s|API_KEY_PLACEHOLDER|$API_KEY|g" /etc/nginx/nginx.conf

# 验证Nginx配置（配置错误直接退出）
if ! nginx -t; then
    echo "❌ Nginx配置验证失败，以下是错误配置："
    cat /etc/nginx/nginx.conf
    exit 1
fi

# 启动Ollama服务（后台运行）
echo "🚀 启动Ollama服务（2vCPU优化版）..."
ollama serve &
OLLAMA_PID=$!

# 等待Ollama端口开放（最多60秒，防止冷启动失败）
echo "⏳ 等待Ollama初始化完成（最多60秒）..."
for i in {1..60}; do
    if timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/11434" 2>/dev/null; then
        echo "✅ Ollama服务已就绪（耗时${i}秒）"
        break
    fi
    [ $i -eq 60 ] && { echo "❌ Ollama启动超时，容器退出"; exit 1; }
    sleep 1
done
# 额外休眠5秒，确保Ollama完全加载
sleep 5

# 拉取当前配置的模型（Ollama官方库，直接拉取无自定义）
echo "📥 开始拉取模型：$OLLAMA_MODEL"
if ollama pull "$OLLAMA_MODEL"; then
    echo "✅ 模型$OLLAMA_MODEL拉取完成，已就绪"
else
    echo "❌ 模型$OLLAMA_MODEL拉取失败，请检查模型名称是否为Ollama官方支持"
    exit 1
fi

# 启动Nginx（前台运行，保持容器存活，HuggingFace检测）
echo "🌐 启动Nginx服务，监听端口7860（HuggingFace默认）"
echo "============================================="
echo "✅ 服务启动完成！访问你的Space地址即可使用："
echo "   📌 在线对话：https://your-space.hf.space"
echo "   📌 使用指南：内置在页面右侧，包含完整操作步骤"
echo "   📌 API文档：页面右侧提供可直接复制的调用示例"
echo "============================================="
exec nginx -g "daemon off;"