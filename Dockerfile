# Use official Python 3.10 base (good for your project)
FROM python:3.10-slim

# Install system dependencies needed for dlib, face_recognition, OpenCV, etc.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    libopenblas-dev \
    liblapack-dev \
    libboost-all-dev \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy only backend code (including model)
COPY backend/ ./backend/

# Move into backend
WORKDIR /app/backend

# Install Python dependencies
RUN pip install --upgrade pip
RUN pip install -r requirements-docker.txt

# Expose a port (for local testing; Render will map it)
EXPOSE 8000

# Gunicorn will listen on PORT (Render sets this)
ENV PORT=8000

# Start the app with gunicorn
CMD ["gunicorn", "server:app", "--bind", "0.0.0.0:8000", "--workers", "1"]
