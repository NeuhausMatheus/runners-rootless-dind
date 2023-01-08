# Sysbox is a container runtime and thus needs host root privileges. As a
# result, this image must be run as a privileged container, and a few resources
# must be bind-mounted to meet Sysbox requirements as well as those of system-level
# apps running in inner containers.

# Notice that within the privileged container,
# inner containers launched with Docker + Sysbox will be strongly isolated from the
# host by Sysbox (e.g., via the Linux user-namespace).

# This DockerFile comes with a Readme.md for free!!

# This is a copy of Sysbox (https://github.com/nestybox/sysbox/blob/master/sysbox-in-docker/Dockerfile.ubuntu-focal) 
# + MySea Actions Runners (https://github.com/msyea/github-actions-runner-rootless)

# You you find every line wrote here on Google. For this reason, I'll save you from all this work:
# I place a link for each copy-n-paste that I made.

FROM ubuntu:20.04

# https://www.sujaypillai.dev/2019/01/2019-01-02-docker-platform-args/
# https://github.com/docker/buildx/issues/510

ARG TARGETPLATFORM=linux/amd64
ARG RUNNER_VERSION=2.300.2
ENV CHANNEL=stable

ARG COMPOSE_VERSION=v2.14.2
ARG DUMB_INIT_VERSION=1.2.5
ARG DEBUG=false

ENV DEBIAN_FRONTEND=noninteractive

COPY .env /.env

SHELL ["/bin/bash", "-o", "pipefail", "-c"]


# https://github.com/balena-os/balena-yocto-scripts/blob/master/automation/Dockerfile_yocto-build-env
# https://linuxhandbook.com/rootless-docker/
# https://thenewstack.io/how-to-run-docker-in-rootless-mode/
# https://docs.docker.com/engine/security/rootless/

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    apt-transport-https \
    apt-utils \
    ca-certificates \
    curl \
    gcc \
    git \
    iproute2 \
    iptables \
    jq \
    libyaml-dev \
    locales \
    lsb-release \
    openssl \
    pigz \
    pkg-config \
    software-properties-common \
    time \
    tzdata \
    uidmap \
    unzip \
    wget \
    xz-utils \
    zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Nice one: https://askubuntu.com/questions/420784/what-do-the-disabled-login-and-gecos-options-of-adduser-command-stand

RUN adduser --disabled-password --gecos "" --uid 1000 runner

COPY githubcli.sh /githubcli.sh

RUN bash /githubcli.sh && rm /githubcli.sh

# https://www.computerhope.com/unix/test.htm

RUN test -n "$TARGETPLATFORM" || (echo "TARGETPLATFORM must be set" && false)

# Read this both below first:
# https://gist.github.com/ali5h/6facd36106e6789060e5077c55387bb2
# https://github.com/msyea/github-actions-runner-rootless/blob/main/Dockerfile.dind

# Copy-n-paste from: https://github.com/CircleCI-Archived/circleci-dockerfiles/blob/master/buildpack-deps/images/buster-curl/dind/Dockerfile

RUN set -eux; \
    addgroup --system dockremap; \
    adduser --system --ingroup dockremap dockremap; \
    echo 'dockremap:165536:65536' >> /etc/subuid; \
    echo 'dockremap:165536:65536' >> /etc/subgid


# Copy-n-paste: https://hub.docker.com/layers/summerwind/actions-runner-dind/v2.280.3-ubuntu-20.04/images/sha256-91fa9f5930ae8c14af13886635535d460097b7fde787258cde895454f5ccba8c?context=explore
# Copy-n-Paste: https://github.com/msyea/github-actions-runner-rootless

ENV RUNNER_ASSETS_DIR=/runnertmp


# copy-n-paste: https://github.com/actions/actions-runner-controller/blob/master/runner/startup.sh

RUN ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && export ARCH \
    && if [ "$ARCH" = "amd64" ]; then export ARCH=x64 ; fi \
    && mkdir -p "$RUNNER_ASSETS_DIR" \
    && cd "$RUNNER_ASSETS_DIR" \
    && curl -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz \
    && ./bin/installdependencies.sh \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/*

ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache

RUN mkdir /opt/hostedtoolcache \
    && chgrp runner /opt/hostedtoolcache \
    && chmod g+rwx /opt/hostedtoolcache
RUN mkdir /opt/statictoolcache \
    && chgrp runner /opt/statictoolcache \
    && chmod g+rwx /opt/statictoolcache

# https://github.com/actions/runner-container-hooks

COPY hooks /etc/arc/hooks/

RUN ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && export ARCH \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && curl -f -L -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH} \
    && chmod +x /usr/local/bin/dumb-init

COPY startup.sh entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/startup.sh /usr/bin/entrypoint.sh


# Nice one: https://www.reddit.com/r/Gentoo/comments/whhasd/should_i_enable_elogind_to_prevent_runuser1000/

RUN mkdir /run/user/1000 \
    && chown runner:runner /run/user/1000 \
    && chmod a+x /run/user/1000

# https://thenewstack.io/how-to-run-docker-in-rootless-mode/

ENV PATH="${PATH}:${HOME}/.local/bin:/home/runner/bin"
ENV ImageOS=ubuntu20
ENV DOCKER_HOST=unix:///run/user/1000/docker.sock
ENV XDG_RUNTIME_DIR=/run/user/1000

RUN echo "PATH=${PATH}" > /etc/environment \
    && echo "ImageOS=${ImageOS}" >> /etc/environment \
    && echo "DOCKER_HOST=${DOCKER_HOST}" >> /etc/environment \
    && echo "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" >> /etc/environment \
    && echo "kernel.unprivileged_userns_clone=1" >> /etc/sysctl.conf

ENV HOME=/home/runner

# https://docs.gitlab.com/ee/ci/docker/using_docker_build.html

USER runner

ENV SKIP_IPTABLES=1
RUN curl -fsSL https://get.docker.com/rootless | sh
COPY --chown=runner:runner docker/daemon.json /home/runner/.config/docker/daemon.json

RUN curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-Linux-x86_64" -o /home/runner/bin/docker-compose ; \
    chmod +x /home/runner/bin/docker-compose

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["startup.sh"]
