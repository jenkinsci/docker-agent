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

RUN mkdir -p /home/${user}/.ssh

# 切换回 jenkins 用户
USER ${user}
