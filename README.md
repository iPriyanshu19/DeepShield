# DeepShield

DeepShield is an Android app for detecting deepfake videos using AI. It features a modern UI, video upload, backend integration, and real-time results.

## Features
- Pick and preview videos from your device
- Generate video thumbnails
- Upload videos to backend for deepfake detection
- View detection results with confidence and processing time
- Modern themed UI
- Python backend for AI inference

<!-- ## Screenshots -->
<!-- Add screenshots here if available -->

## Getting Started

### Prerequisites
- Flutter SDK (https://flutter.dev/docs/get-started/install)
- Python 3.10+ (for backend)
- Android/iOS device or emulator

### Installation
1. **Clone the repository:**
   ```sh
   git clone https://github.com/iPriyanshu19/deepshield.git
   cd deepshield
   ```
2. **Install dependencies:**
   ```sh
   flutter pub get
   ```
3. **Run the Flutter app:**
   ```sh
   flutter run
   ```
4. **Set up the Python backend:**
   - Navigate to `backend/`
   - Create and activate a virtual environment (optional)
   - Install requirements:
     ```sh
     pip install -r requirements.txt
     ```
   - Start the backend server:
     ```sh
     python server.py
     ```

## Project Structure
```
lib/
  main.dart
  screens/
    home_screen.dart
    login_screen.dart
    result_screen.dart
backend/
  server.py
  requirements.txt
  model/
    df_model.pt
assets/
  logo.png
  glogo.png
```

## Usage
- Launch the app and log in
- Pick a video to analyze
- View the thumbnail and upload for deepfake detection
- See results in a dedicated result screen

## Contributing
Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.
