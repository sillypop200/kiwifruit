# KiwiFruit

KiwiFruit is a SwiftUI iOS app prototype focused on reading sessions, reflection posts and social features.

Overview
- Social feed with infinite scroll (reflection posts)
- Profile pages with post grids
- Create reflection posts (image URL + caption)
- Persistent likes and user session token
- Mock and REST API client support; example Flask API spec included

Project layout (important files)
- `kiwifruit/kiwifruit/kiwifruit/Models.swift`: `User` and `Post` models used across app.
- `kiwifruit/kiwifruit/kiwifruit/APIClient.swift`: `APIClientProtocol`, `MockAPIClient`, `RESTAPIClient` (network layer).
- `kiwifruit/kiwifruit/kiwifruit/MockData.swift`: Mock data for local development.
- `kiwifruit/kiwifruit/kiwifruit/SessionStore.swift`: `@Observable` session store that persists a token and user id and wires `RESTAPIClient` as `APIClient.shared`.
- `kiwifruit/kiwifruit/kiwifruit/LikesStore.swift`: `@Observable` persistent likes store exposed via an `EnvironmentKey`.
- `kiwifruit/kiwifruit/kiwifruit/FeedViewModel.swift`: View model for feed with paging and prepend support.
- `kiwifruit/kiwifruit/kiwifruit/FeedView.swift`: Main feed UI with infinite scroll and create-post button.
- `kiwifruit/kiwifruit/kiwifruit/PostRow.swift`: UI for a single post, like button and avatar navigation.
- `kiwifruit/kiwifruit/kiwifruit/ProfileView.swift`: Profile page and posts grid.
- `kiwifruit/kiwifruit/kiwifruit/CreatePostView.swift`: Simple form for creating reflection posts.
- `kiwifruit/kiwifruit/kiwifruit/ApiSpec.md`: API contract and small Flask example server.

How the pieces connect
- Views call into view models (e.g., `FeedView` -> `FeedViewModel`).
- View models call `APIClient.shared` for network I/O. Swap implementations by setting `APIClient.shared = RESTAPIClient(baseURL:)`.
- `SessionStore` holds authentication token and user id; it persists them to `UserDefaults`, sets `APIClient.shared` to a `RESTAPIClient` and injects the token into requests.
- `LikesStore` persists liked post ids in `UserDefaults` and is available via `@Environment(\.likesStore)`.

Running locally (Xcode)
1. Open `kiwifruit.xcodeproj` in Xcode.
2. Select a simulator (iOS 16+ recommended) and run.
3. By default the app uses mock data. To point to your Flask backend update `SessionStore` initialization in `ContentView` to set the correct base URL, or create a `SessionStore(baseURL:)` and inject it.

Flask backend wiring notes
- The app expects the API endpoints described in `ApiSpec.md`.
- When a session token exists, `SessionStore` configures `RESTAPIClient` to include `Authorization: Bearer <token>` on requests.
- Example: after authenticating via `POST /sessions`, call `sessionStore.save(token:userId:)` to persist and apply the token.

Next recommended improvements
- Replace image URL posting with actual image upload endpoints (multipart/form-data).
- Add proper user authentication and secure storage (Keychain) for tokens.
- Add tests for view models and API decoding.

