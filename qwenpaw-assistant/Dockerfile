FROM debian:trixie
# https://hub.docker.com/_/python?xk=ShowRecommendedBadge&xt=Enabled
# https://hub.docker.com/_/debian?xk=ShowRecommendedBadge&xt=Disabled
WORKDIR /root

# 安装依赖：nginx(密码) + HF官方备份库 + inotify 实时监听……
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx apache2-utils inotify-tools firefox-esr fonts-wqy-zenhei curl wget git gh tmux tar unzip python3 python3-pip chromium ffmpeg imagemagick cron git wget htop lsof net-tools iproute2 && \    
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
RUN python3 -m pip install --upgrade qwenpaw huggingface-hub uv nacos-sdk-python --break-system-packages


COPY start.sh .
RUN chmod +x start.sh
EXPOSE 7860

CMD ["./start.sh"]
