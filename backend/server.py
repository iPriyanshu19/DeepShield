from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
import os
import torch
from torchvision import transforms
from torch.utils.data.dataset import Dataset
import numpy as np
import cv2
# import face_recognition
import time
import traceback
import logging
from torch import nn
import torch.nn.functional as F
from torchvision import models
import warnings
warnings.filterwarnings("ignore")

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Upload folder
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'Uploaded_Files')
MODEL_PATH = os.path.join(BASE_DIR, 'model', 'df_model.pt')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

DEVICE = torch.device("cpu")

# OpenCV face detector (Haar cascade)
FACE_CASCADE = cv2.CascadeClassifier(
    os.path.join(cv2.data.haarcascades, "haarcascade_frontalface_default.xml")
)


# Flask app
app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 500 * 1024 * 1024  # 500MB max file size

# ------------------------
# Model Definition
# ------------------------
class Model(nn.Module):
    def __init__(self, num_classes, latent_dim=2048, lstm_layers=1, hidden_dim=2048, bidirectional=False):
        super(Model, self).__init__()
        model = models.resnext50_32x4d(pretrained=True)
        self.model = nn.Sequential(*list(model.children())[:-2])
        self.lstm = nn.LSTM(latent_dim, hidden_dim, lstm_layers, bidirectional)
        self.dp = nn.Dropout(0.4)
        self.linear1 = nn.Linear(2048, num_classes)
        self.avgpool = nn.AdaptiveAvgPool2d(1)

    def forward(self, x):
        batch_size, seq_length, c, h, w = x.shape
        x = x.view(batch_size * seq_length, c, h, w)
        fmap = self.model(x)
        x = self.avgpool(fmap)
        x = x.view(batch_size, seq_length, 2048)
        x_lstm, _ = self.lstm(x, None)
        return fmap, self.dp(self.linear1(x_lstm[:, -1, :]))

# ------------------------
# Dataset for validation
# ------------------------
class ValidationDataset(Dataset):
    def __init__(self, video_names, sequence_length=20, transform=None):
        self.video_names = video_names
        self.transform = transform
        self.count = sequence_length

    def __len__(self):
        return len(self.video_names)

    def __getitem__(self, idx):
        video_path = self.video_names[idx]
        frames = []

        for i, frame in enumerate(self.frame_extract(video_path)):
            # frame: BGR (OpenCV)
            # 1) detect faces
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = FACE_CASCADE.detectMultiScale(
                gray,
                scaleFactor=1.1,
                minNeighbors=5,
                minSize=(30, 30),
            )

            # 2) crop around first detected face (if any)
            if len(faces) > 0:
                (x, y, w, h) = faces[0]
                frame = frame[y:y+h, x:x+w]

            # 3) transform and collect
            frames.append(self.transform(frame))

            if len(frames) == self.count:
                break

        if len(frames) == 0:
            raise ValueError("No frames extracted from video")

        # pad if less than count
        while len(frames) < self.count:
            frames.append(frames[-1])

        frames = torch.stack(frames)
        frames = frames[:self.count]
        return frames.unsqueeze(0)

    def frame_extract(self, path):
        vidObj = cv2.VideoCapture(path)
        success = True
        while success:
            success, image = vidObj.read()
            if success:
                yield image

'''
# Alternative Dataset using face_recognition library (Original version)
class ValidationDataset(Dataset):
    def __init__(self, video_names, sequence_length=20, transform=None):
        self.video_names = video_names
        self.transform = transform
        self.count = sequence_length

    def __len__(self):
        return len(self.video_names)

    def __getitem__(self, idx):
        video_path = self.video_names[idx]
        frames = []
        for i, frame in enumerate(self.frame_extract(video_path)):
            faces = face_recognition.face_locations(frame)
            try:
                top, right, bottom, left = faces[0]
                frame = frame[top:bottom, left:right, :]
            except:
                pass
            frames.append(self.transform(frame))
            if len(frames) == self.count:
                break
        frames = torch.stack(frames)
        frames = frames[:self.count]
        return frames.unsqueeze(0)

    def frame_extract(self, path):
        vidObj = cv2.VideoCapture(path)
        success = True
        while success:
            success, image = vidObj.read()
            if success:
                yield image
'''

# ------------------------
# Global transform & model (load ONCE)
# ------------------------
IM_SIZE = 112
MEAN = [0.485, 0.456, 0.406]
STD = [0.229, 0.224, 0.225]

transform = transforms.Compose([
    transforms.ToPILImage(),
    transforms.Resize((IM_SIZE, IM_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(MEAN, STD)
])

if not os.path.exists(MODEL_PATH):
    raise FileNotFoundError(f"Model file not found at {MODEL_PATH}")

logger.info(f"Loading model from: {MODEL_PATH}")
model = Model(num_classes=2)
state_dict = torch.load(MODEL_PATH, map_location=DEVICE)
model.load_state_dict(state_dict)
model.to(DEVICE)
model.eval()
logger.info("Model loaded and ready.")


# ------------------------
# Prediction
# ------------------------
def predict(model, img):
    img = img.to(DEVICE)
    with torch.no_grad():
        fmap, logits = model(img)
        logits = F.softmax(logits, dim=1)
        _, prediction = torch.max(logits, 1)
        confidence = logits[:, int(prediction.item())].item() * 100
        return [int(prediction.item()), confidence]

def detectFakeVideo(videoPath):
    start_time = time.time()

    dataset = ValidationDataset([videoPath], sequence_length=20, transform=transform)
    frames = dataset[0]          # shape (1, seq, C, H, W)
    prediction = predict(model, frames)

    processing_time = time.time() - start_time
    return prediction, processing_time

# ------------------------
# API Routes
# ------------------------
@app.route("/")
def home():
    return jsonify({"message": "Deepfake Detection API is running"})

@app.route("/detect", methods=["POST"])
def detect():
    if 'video' not in request.files:
        return jsonify({"error": "No video file uploaded"}), 400

    video = request.files['video']
    if video.filename == '':
        return jsonify({"error": "No video file selected"}), 400

    if not video.filename.lower().endswith(('.mp4', '.avi', '.mov')):
        return jsonify({"error": "Invalid file format. Please upload MP4, AVI, or MOV"}), 400

    video_filename = secure_filename(video.filename)
    video_path = os.path.join(app.config['UPLOAD_FOLDER'], video_filename)
    video.save(video_path)

    try:
        logger.info(f"Processing video: {video_filename}")
        prediction, processing_time = detectFakeVideo(video_path)

        output = "FAKE" if prediction[0] == 0 else "REAL"
        confidence = prediction[1]

        response = {
            "output": output,
            "confidence": confidence,
            "processing_time": round(processing_time, 2)
        }

        os.remove(video_path)
        return jsonify(response)

    except Exception as e:
        if os.path.exists(video_path):
            os.remove(video_path)
        error_msg = str(e)
        logger.error(f"Error processing video: {error_msg}")
        traceback.print_exc()
        return jsonify({"error": f"Error processing video: {error_msg}"}), 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
