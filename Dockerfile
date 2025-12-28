FROM ubuntu:24.04

WORKDIR /munin

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    llvm \
    clang \
    git \
    curl \
    make \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Odin
RUN git clone --depth 1 --branch dev-2025-11 https://github.com/odin-lang/Odin.git /opt/odin \
    && cd /opt/odin \
    && make release \
    && ln -s /opt/odin/odin /usr/local/bin/odin

COPY . .

CMD ["make", "test"]
