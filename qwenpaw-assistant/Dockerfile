FROM python:3.11-slim

WORKDIR /app

# 安装依赖：nginx(密码) + HF官方备份库
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx apache2-utils && \
    rm -rf /var/lib/apt/lists/*

# 时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime

# 中文环境
RUN apt update && apt install -y locales --no-install-recommends && \
    echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    apt clean && rm -rf /var/lib/apt/lists/*

ENV LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8

# 核心：PIP安装 CoPaw + HuggingFace官方备份工具
RUN pip install --upgrade pip qwenpaw huggingface-hub

COPY start.sh .
RUN chmod +x start.sh
EXPOSE 7860

CMD ["./start.sh"]