# ============================================
# Stage 1: Builder - 构建 Rust 应用
# ============================================
FROM rust:latest AS builder

WORKDIR /app

# 复制 Cargo 配置文件（利用 Docker 缓存层）
COPY Cargo.toml Cargo.lock* ./

# 创建虚拟 src 目录以缓存依赖
RUN mkdir -p src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# 复制实际源代码
COPY src ./src

# 重新构建（这次是实际的应用）
RUN touch src/main.rs && \
    cargo build --release

# ============================================
# Stage 2: Runtime - 最小化运行环境
# ============================================
FROM debian:bookworm-slim

# 安装运行时依赖（SSL 证书等）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        libssl3 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/target/release/kiro-rs /app/kiro-rs

# 创建配置目录
RUN mkdir -p /app/config

# 设置非 root 用户运行（安全最佳实践）
RUN useradd -r -s /bin/false kiro && \
    chown -R kiro:kiro /app
USER kiro

# 默认端口
EXPOSE 8990

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8990/v1/models || exit 1

# 启动命令
ENTRYPOINT ["/app/kiro-rs"]
CMD ["-c", "/app/config/config.json", "--credentials", "/app/config/credentials.json"]
