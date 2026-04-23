FROM python:3.10-slim

WORKDIR /app

# System dependencies for scikit-learn & scientific modules
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all resources including the .pkl payload
COPY . .

# Expose API port
EXPOSE 8000

# Start Uvicorn engine (1 worker limits RAM usage to under 512MB for free tiers)
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1"]
