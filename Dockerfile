FROM node:24-bookworm

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y \
    tzdata locales git ripgrep ca-certificates vim neovim sudo \
 && sed -i 's/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen \
 && ln -snf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
 && echo Asia/Tokyo > /etc/timezone \
 && rm -rf /var/lib/apt/lists/*

ENV TZ=Asia/Tokyo
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN npm install -g npm@12.0.1 && \
    npm install -g \
        --allow-scripts=@anthropic-ai/claude-code \
        @anthropic-ai/claude-code

ENV DISABLE_AUTOUPDATER=1

RUN mkdir -p /home/node/.claude && \
    chown -R node:node /home/node/.claude

USER node
WORKDIR /workspace

CMD ["claude"]
