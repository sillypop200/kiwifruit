
# KiwiFruit

KiwiFruit is a SwiftUI iOS prototype that helps readers share short reflection posts about their reading sessions, track streaks and challenges, and stay focused. This repository contains a focused, easy-to-extend foundation you can connect to a Flask backend or iterate from Figma designs.

Core features implemented (prototype)
- Login flow (username-based, prototyped) with `SessionStore` and token persistence.
- Create reflection posts using the device photo library (PhotosPicker) and multipart upload support.
- Infinite-scroll social feed with shared `PostsStore` as single source of truth.
- Profile page showing posts authored by a user.
- Local persistent likes (optimistic UI) and comments (local persistence) with optional server sync endpoints.
- Tabs scaffold: Home, Profile, Challenges, Focus (Challenges/Focus placeholders for future work).

Project layout (concise)
- Models/: `Models.swift` (Post, User, Comment)
- Services/: `APIClient.swift`, `SessionStore.swift`, `PostsStore.swift`, `LikesStore.swift`, `CommentsStore.swift`
- Views/: `FeedView.swift`, `PostRow.swift`, `ProfileView.swift`, `CreatePostView.swift`, `LoginView.swift`, `CommentsView.swift`
- Support: `MockData.swift`, `ApiSpec.md`, and README.

Key design notes (for future Figma integration)
- Small focused views: each SwiftUI `View` is a single screen or cell (e.g., `PostRow` maps directly to a post component in Figma).
- Central stores: `PostsStore`, `LikesStore`, `CommentsStore`, and `SessionStore` provide clear wiring points for state; map these to state tiles in your Figma documentation.
- The networking layer is protocol-based (`APIClientProtocol`) so you can swap mocks for a REST client during integration testing.

How to run locally
1. Open the project in Xcode:
```bash
open kiwifruit.xcodeproj
```
2. Run on a simulator or device (iOS 16+ recommended). PhotosPicker works best on real device or simulator populated with photos.
3. By default the app uses `MockAPIClient`. To point at your Flask backend, instantiate `SessionStore(baseURL:)` with your API URL and ensure `APIClient.shared` is the `RESTAPIClient` (this is done automatically when `SessionStore` is initialized).

API and backend notes
- See `ApiSpec.md` for endpoint suggestions (posts, sessions, likes). A prototype Flask server is included in the spec with multipart upload and like endpoints.
- Authentication: the prototype stores a simple token in `UserDefaults`. For production, migrate to Keychain and full auth flows.

Developer notes (how pieces connect)
- `PostsStore` is the canonical feed source; `FeedView` and `ProfileView` read from it so new posts appear everywhere.
- `CreatePostView` uploads images (multipart) and prepends the created `Post` into `PostsStore` so it appears at the top of the feed.
- `PostRow` uses `LikesStore` for optimistic likes and calls `APIClient.likePost`/`unlikePost` to reconcile server counts; `PostsStore.updateLikes` applies server counts.
- `CommentsStore` is local and simple for prototype comment storage; replace with server endpoints later.

Next steps / suggestions
- Replace `UserDefaults` token storage with Keychain for security.
- Implement server-side persistent storage and replace `MockAPIClient` with `RESTAPIClient(baseURL:)`.
- Add image upload endpoint on the server (multipart/form-data) and return canonical `Post` JSON.
- Add UI polish and theme tokens (Asset Catalog color `KiwiGreen`) to match your Figma designs.

If you want, I can now:
- Add a complete Flask example server implementing multipart upload, likes, and sessions.
- Reorganize files into Xcode groups/folders and update the `.xcodeproj` to match.
- Replace `UserDefaults` usage with Keychain for session tokens.

