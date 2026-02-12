Overview
========

KiwiFruit is a social reading app. This document covers the backend REST API
served by the Flask application in ``server/app.py``.

Base URL
--------

During local development the server runs on::

    http://localhost:5000

Authentication
--------------

Most write endpoints require a valid session token obtained from
``POST /sessions``. The token can be supplied in two ways:

* **Authorization header** (preferred for API clients)::

      Authorization: Bearer <token>

* **Session cookie** (set automatically by the server on login, for
  browser-based clients)::

      Cookie: session=<token>

Data Models
-----------

User object
~~~~~~~~~~~

Returned by user-related endpoints::

    {
      "id":          "alice",
      "username":    "alice",
      "displayName": "Alice Example",
      "avatarURL":   "http://localhost:5000/uploads/default.jpg"
    }

Post object
~~~~~~~~~~~

Returned by feed and post-detail endpoints::

    {
      "id":       "123",
      "author":   { <user object> },
      "imageURL": "http://localhost:5000/uploads/abcd1234.jpg",
      "caption":  "Lovely day for kiwis!",
      "likes":    4
    }

Comment object
~~~~~~~~~~~~~~

Returned by ``GET /posts/<post_id>/comments``::

    {
      "id":        "7",
      "author":    { <user object> },
      "text":      "Great read!",
      "createdAt": "2026-01-30T12:34:56+00:00"
    }

Quick-start
-----------

1. **Create an account**::

       POST /users
       Content-Type: application/json

       { "username": "alice", "password": "s3cr3t", "fullname": "Alice Example" }

2. **Log in to get a token**::

       POST /sessions
       Content-Type: application/json

       { "username": "alice", "password": "s3cr3t" }

   Response includes ``token``; pass it as ``Authorization: Bearer <token>``
   on all subsequent authenticated requests.

3. **Fetch the feed**::

       GET /posts?page=0&pageSize=10

4. **Create a post** (multipart form)::

       POST /posts
       Authorization: Bearer <token>
       Content-Type: multipart/form-data

       file=<image file>
       caption=Lovely day for kiwis!
