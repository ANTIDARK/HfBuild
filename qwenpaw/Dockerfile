FROM python:3.13-slim

WORKDIR /root

# 安装依赖：HF官方备份库 + inotify 实时监听……
RUN apt-get update && \
    apt-get install -y --no-install-recommends inotify-tools firefox-esr fonts-wqy-zenhei curl wget git gh tmux tar unzip chromium ffmpeg imagemagick cron git wget htop lsof net-tools iproute2 && \
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

# 核心：PIP安装 qwenpaw + HuggingFace官方备份工具
RUN python3 -m pip install --upgrade pip qwenpaw huggingface-hub uv nacos-sdk-python qwenpaw[whisper]


COPY start.sh .
RUN chmod +x start.sh
EXPOSE 7860

CMD ["./start.sh"]
