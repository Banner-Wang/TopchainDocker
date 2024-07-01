# 使用 Ubuntu 22.04 作为基础镜像
FROM ubuntu:22.04

ENV PYTHON_VERSION=3.10

# 设置工作目录
WORKDIR /chain

# 更新软件包并安装必要的软件包
RUN apt-get update && apt-get install -y \
    python3-dev \
    build-essential \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/* \
    && apt clean all

RUN pip3 install \
    loguru \
    DingtalkChatbot


# 将指定的信息写入 /etc/profile
RUN echo 'unset -f pathmunge' >> /etc/profile && \
    echo 'export TMOUT=360' >> /etc/profile && \
    echo 'ulimit -c unlimited' >> /etc/profile && \
    echo 'export TOPIO_HOME=/chain' >> /etc/profile

# 暴露必要的 TCP 端口
EXPOSE 19081/tcp
EXPOSE 19082/tcp
EXPOSE 19085/tcp
EXPOSE 8080/tcp

# 暴露必要的 UDP 端口
EXPOSE 9000/udp
EXPOSE 9001/udp

#COPY ./bwlist.json /chain
#COPY ./topio /script
COPY ./run.sh /script/
COPY ./startupcheck.sh /script/
COPY ./livecheck.sh /script/
COPY ./topargus-agent /script/

USER root

CMD ["bash", "/script/run.sh"]
