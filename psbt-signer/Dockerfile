FROM python:3.12-slim

RUN groupadd -g 1000 signer && \
    useradd -m -u 1000 -g signer signer

USER signer

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

RUN pip install git+https://github.com/euer-org/Ttpm2.git

# Application source
COPY . .

# Create directories for persistent data
RUN mkdir -p /data /wallets

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
