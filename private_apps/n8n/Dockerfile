FROM n8nio/n8n:latest
USER root

# Install dependencies
RUN apk add --no-cache wget tar xz

# Install Pandoc
RUN wget https://github.com/jgm/pandoc/releases/download/3.1.11/pandoc-3.1.11-linux-amd64.tar.gz && tar -xzf pandoc-3.1.11-linux-amd64.tar.gz --strip-components 1 -C /usr/local \ && rm pandoc-3.1.11-linux-amd64.tar.gz

RUN npm install -g @mozilla/readability linkedom turndown

USER node
