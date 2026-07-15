FROM python:3.14-slim@sha256:b877e50bd90de10af8d82c57a022fc2e0dc731c5320d762a27986facfc3355c1

# System dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    pkg-config \
    libssl-dev \
    libffi-dev \
    libsecp256k1-dev \
    tpm2-tools \
    libtss2-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN (getent group 1000 || groupadd -g 1000 signer) \
    && (getent passwd 1000 || useradd -u 1000 -g 1000 -M -s /usr/sbin/nologin signer)

WORKDIR /app

# Python dependencies
COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Application source
COPY . .

# Create directories for persistent data
RUN mkdir -p /data /wallets \
    && chown -R 1000:1000 /app /data /wallets

USER 1000

EXPOSE 8080

CMD ["uvicorn", "app.signer:app", "--host", "0.0.0.0", "--port", "8080"]
