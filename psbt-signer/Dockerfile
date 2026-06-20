FROM python:3.12-slim

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

WORKDIR /app

# Python dependencies
COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Application source
COPY . .

# Create directories for persistent data
RUN mkdir -p /data /wallets

EXPOSE 8080

CMD ["uvicorn", "app.signer:app", "--host", "0.0.0.0", "--port", "8080"]
