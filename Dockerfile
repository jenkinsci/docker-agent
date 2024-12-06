FROM jenkins/inbound-agent:latest

# 切换到 root 用户
USER root

# 更新包列表并安装 sudo 和 rsync
RUN apt-get -yqq update \
  && apt-get --yes --no-install-recommends install \
    ca-certificates \
    curl \
    fontconfig \
    git \
    git-lfs \
    less \
    netbase \
    openssh-client \
    patch \
    tzdata \
    rsync \
    sudo \
    python3 \
    make \
  && apt-get clean \
  && rm -rf /tmp/* /var/cache/* /var/lib/apt/lists/*

# 添加 jenkins 用户到 sudoers 文件并允许无密码 sudo
RUN chmod +w /etc/sudoers && echo 'jenkins ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers && chmod -r /etc/sudoers

RUN sudo apt-get update
RUN sudo apt-get install ca-certificates curl
RUN sudo install -m 0755 -d /etc/apt/keyrings
RUN sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
RUN sudo chmod a+r /etc/apt/keyrings/docker.asc

RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN sudo apt-get update
#RUN sudo apt-get --yes --no-install-recommends install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
RUN sudo apt-get install docker-ce docker-ce-cli containerd.io
RUN sudo service docker start

# 切换回 jenkins 用户
USER ${user}

RUN mkdir -p /home/${user}/.ssh
RUN mkdir -p /home/${user}/store
