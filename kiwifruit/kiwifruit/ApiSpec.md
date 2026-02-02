# KiwiFruit API Spec (server-backed MVP)

Base URL: `http://localhost:5000` (development)

Authentication: Bearer token in `Authorization` header (Bearer <token>). Some endpoints may be public for early development.

---

## Supported Endpoints (MVP)

- GET /posts?page={page}&pageSize={pageSize}
  - Returns a paginated list of posts. Each post contains `id`, `author`, `imageURL`, `caption`, `likes`, `createdAt`.

- POST /sessions
  - Create or retrieve a session for a username. Body: JSON `{ "username": "alice" }`. Returns `{ "token": "...", "userId": "..." }`.

- POST /posts
  - Create a new post. Expects `multipart/form-data` with `file` (image) and optional `caption` field. Requires `Authorization` header.

- POST /posts/{postId}/like
  - Like a post. Requires `Authorization` header. Returns `{ "likes": <count> }`.

- DELETE /posts/{postId}/like
  - Remove like. Requires `Authorization` header. Returns `{ "likes": <count> }`.

- POST /comments
  - Manage comments via `operation` form field. For create: `operation=create`, `postid`, `text`. For delete: `operation=delete`, `commentid`. Requires `Authorization` header.

- GET /users/{userId}
  - Retrieve user profile (minimal fields).

- GET /uploads/{filename}
  - Serve uploaded image files.

---

## Example Post JSON

```json
{
  "id": 123,
  "author": {
    "id": "user-uuid",
    "username": "alice",
    "displayName": "Alice Example",
    "avatarURL": "http://localhost:5000/uploads/default.jpg"
  },
  "imageURL": "http://localhost:5000/uploads/abcd1234.jpg",
  "caption": "Lovely day for kiwis!",
  "likes": 4,
  "createdAt": "2026-01-30T12:34:56Z"
}
```

---

Notes for frontend wiring

- Use `GET /posts` to populate the feed; use `page` and `pageSize` for pagination.
- Use `POST /sessions` with `{ "username": "..." }` to get a `token`, persist it locally, and send `Authorization: Bearer <token>` on protected requests.
- Use `POST /posts` with `multipart/form-data` to upload images.

