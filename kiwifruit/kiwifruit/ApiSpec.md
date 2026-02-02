# KiwiFruit API Spec (Minimal)

Base URL: `https://api.kiwifruit.example.com`

Authentication: Bearer token in `Authorization` header (Bearer <token>). For early development, endpoints may be public.

---

## Endpoints

- GET /posts?page={page}&pageSize={pageSize}
  - Returns paginated list of posts. Each post contains `id`, `author`, `imageURL`, `caption`, `likes`, `createdAt`.

- GET /users/{userId}
  - Returns a `User` object by id.

- POST /sessions
  - Create a reading session. Body: `{ "userId": "...", "bookId": "...", "durationMinutes": 30 }`.

- GET /books?query=...
  - Search books.

- GET /streaks/{userId}
  - Returns reading streak info for user.

- GET /challenges
  - List active challenges.

- POST /posts
  - Create a reflection post. Body: `{ "authorId": "...", "imageURL": "...", "caption": "..." }`.

---

## Example Post JSON

```json
{
  "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "author": {
    "id": "...",
    "username": "reader1",
    "displayName": "Reader One",
    "avatarURL": "https://..."
  },
  "imageURL": "https://...",
  "caption": "Loved this passage about curiosity.",
  "likes": 12,
  "createdAt": "2026-01-30T12:34:56Z"
}
```

---

## Flask Example (very small)

```python
from flask import Flask, jsonify, request
from uuid import uuid4

app = Flask(__name__)

@app.route('/posts')
def posts():
    page = int(request.args.get('page', 0))
    page_size = int(request.args.get('pageSize', 10))
    # In real app: query DB. Here return mock data.
    items = []
    for i in range(page_size):
        items.append({
            'id': str(uuid4()),
            'author': {
                'id': str(uuid4()),
                'username': 'kiwi_botanist',
                'displayName': 'Kiwi Lover',
                'avatarURL': 'https://picsum.photos/seed/avatar/100'
            },
            'imageURL': f'https://picsum.photos/seed/kiwi{page*page_size + i}/600/600',
            'caption': f'Fresh kiwi vibes #{page*page_size + i}',
            'likes': 5,
            'createdAt': '2026-01-01T00:00:00Z'
        })
    return jsonify(items)

if __name__ == '__main__':
    app.run(debug=True)
```

---

## Notes for frontend wiring

- Use `GET /posts` to populate feed; page and pageSize for infinite scroll.
- Use `POST /posts` to create reflection posts.
- Store minimal user session locally (token) and send `Authorization` header.
