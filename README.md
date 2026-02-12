# KiwiFruit

**Connect directly with your friends and stay focused to reclaim your reading time.**

KiwiFruit is a social reading ecosystem that combines focus management, computer vision, and social accountability to help users build consistent reading habits. It addresses distracted reading by integrating focus tools, mood mapping to track emotional responses, and a social feed to share progress.

The application is composed of a native iOS client (SwiftUI) and a Python backend (Flask).

## Project Structure

The repository is organized into two main components: the iOS client and the backend server.

### iOS Client (kiwifruit/)
The frontend is built using Swift and SwiftUI, utilizing an MVVM architecture with dedicated Stores for state management.

* **Views:** UI components including FeedView, PostDetailView, ProfileView, and Login/SignUpView.
* **Stores:** State management handles are separated by domain:
    * SessionStore.swift: Manages active reading sessions and timers.
    * PostsStore.swift, LikesStore.swift, CommentsStore.swift: Manage social interactions and feed data.
* **Services:** APIClient.swift handles networking and communication with the Flask backend.
* **Models:** Data definitions (Models.swift) and mock data generation.

### Backend Server (server/)
The backend is a Flask application managing data persistence and API endpoints.

* **app.py:** The entry point for the Flask application.
* **Database:** Uses SQLite (kiwifruit.db) with a defined schema (schema.sql).
* **Uploads:** Stores user-generated content and placeholder images.
* **Utilities:** Includes scripts like reset_db_and_uploads.sh for database initialization.

## Key Features

### Social & Community
* **Feed System:** View friends' reading sessions, status updates, and progress.
* **Interactions:** Comment on and like posts regarding reading milestones.
* **Profile Management:** Track personal reading history and streaks.

### Reading & Focus
* **Session Management:** A dedicated Orchestrator manages the state (idle, running, paused) of reading sessions.
* **Focus Controller:** Integrates with iOS FamilyControls and ManagedSettings to block distracting apps during active sessions.
* **Mood Map:** Uses Computer Vision (EmotiEffLib) to track user emotions during reading, creating a "Mood Map" of the experience.

### Library & Intelligence
* **Scan Pipeline:** Adds books via barcode scanning (AVFoundation) or OCR (Vision).
* **Recommendation Engine:** Utilizes a multi-signal approach (history, behavior, friends) to suggest books.

## Tech Stack

### iOS Client
* **Language:** Swift
* **Framework:** SwiftUI
* **Core Libraries:** AVFoundation (Scanning), Vision (OCR), FamilyControls (Focus).

### Backend
* **Language:** Python
* **Framework:** Flask
* **Database:** SQLite (Development/Current), SQL (Architecture).

## Getting Started

### Backend Setup
1.  Navigate to the server directory:
    ```bash
    cd server
    ```
2.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
3.  Initialize the database:
    ```bash
    ./reset_db_and_uploads.sh
    ```
4.  Run the application:
    ```bash
    python app.py
    ```

### iOS Client Setup
1.  Navigate to the project directory:
    ```bash
    cd kiwifruit
    ```
2.  Open the project in Xcode:
    ```bash
    open kiwifruit.xcodeproj
    ```
3.  Ensure the APIClient.swift is pointing to your local Flask server URL.
4.  Build and run on a simulator or physical device.

## Documentation
* **API Specification:** Refer to kiwifruit/kiwifruit/ApiSpec.md for endpoint details.

## Team

| Name | Role | Focus Area |
| :--- | :--- | :--- |
| Anurag Krosuru | Backend, Full-Stack | Reading Sessions, Timer, Backend |
| Savannah Brown | Backend, Full-Stack | Vision-based book recognition |
| Zixiao Ma | Frontend, UI/UX | App Blocking Timer |
| Tingrui Zhang | Computer Vision | Vision-based concentration/mood monitor |
| Shawn Dong | UI/UX | UI Design, Mood extraction support |
| Swesik Ramineni | Infrastructure, Backend | Speed reading, Home page UI |
| Bonnie Huynh | UI/UX, Full-Stack | Book Recommendations, Rec Engine |
| Varun Talluri | ML, Database Mgmt | Reading updates, Challenges, Streaks |