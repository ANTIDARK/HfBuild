# 使用 Ollama 官方预编译镜像
FROM ollama/ollama:latest

# 安装 Nginx
RUN apt-get update && apt-get install -y nginx && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制启动脚本
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 创建 Ollama 模型目录
RUN mkdir -p /root/.ollama

# 暴露 HuggingFace Spaces 要求的端口
EXPOSE 7860

# 使用启动脚本
ENTRYPOINT ["/app/entrypoint.sh"]