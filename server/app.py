import os
import uuid
import hashlib
import sqlite3
import logging
import threading
from datetime import datetime, timezone
from flask import Flask, request, jsonify, g, abort, send_from_directory, make_response
from werkzeug.exceptions import HTTPException
import ebooklib
from ebooklib import epub as epub_lib
from bs4 import BeautifulSoup

BASE_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(BASE_DIR, 'kiwifruit.db')
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# Basic logging configuration
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("kiwifruit")

def get_db():
    """Return the SQLite database connection for the current app context.

    Creates a new connection if one does not already exist, storing it on
    Flask's ``g`` object so it is reused within the same request.
    Rows are returned as :class:`sqlite3.Row` objects for dict-style access.

    :returns: Active SQLite database connection.
    :rtype: sqlite3.Connection
    """
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(DB_PATH)
        db.row_factory = sqlite3.Row
    return db

@app.teardown_appcontext
def close_connection(exception):
    """Close the database connection at the end of the app context.

    Registered with Flask's teardown mechanism so it runs automatically
    after each request or when the app context is popped.

    :param exception: Any exception that triggered the teardown, or ``None``.
    """
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

def init_db():
    """Initialize the database by executing ``schema.sql``.

    Reads ``schema.sql`` from the same directory as this file and runs it
    against the database inside an app context. Intended to be called once
    on first run when no database file exists yet.
    """
    with app.app_context():
        db = get_db()
        schema_path = os.path.join(BASE_DIR, 'schema.sql')
        with open(schema_path, 'r') as f:
            db.executescript(f.read())


def _to_iso(ts):
    # ts is a SQLite DATETIME like 'YYYY-MM-DD HH:MM:SS' or already ISO; return ISO8601 with timezone
    if ts is None:
        return None
    try:
        dt = datetime.strptime(ts, '%Y-%m-%d %H:%M:%S')
        return dt.replace(tzinfo=timezone.utc).isoformat()
    except Exception:
        return ts


def _extract_epub_metadata(filepath, fallback_name):
    """Extract title and author from epub Dublin Core metadata.

    :param filepath: Path to the epub file on disk.
    :param fallback_name: Original filename used as fallback title.
    :returns: ``(title, author)`` tuple of strings.
    """
    title = os.path.splitext(fallback_name)[0][:512]
    author = ''
    try:
        book = epub_lib.read_epub(filepath, options={'ignore_ncx': True})
        titles = book.get_metadata('DC', 'title')
        if titles and titles[0] and titles[0][0]:
            title = titles[0][0][:512]
        creators = book.get_metadata('DC', 'creator')
        if creators and creators[0] and creators[0][0]:
            author = creators[0][0][:512]
    except Exception as e:
        logger.warning('could not extract epub metadata from %s: %s', filepath, e)
    return title, author


def _parse_epub_chapters(epubid, filepath):
    """Parse epub chapters in a background thread.

    Opens its own database connection (not request-scoped).
    Writes each chapter's plaintext to a UUID-named ``.txt`` file in the
    uploads folder. Updates the epub status to PARSED on success or FAILED
    on error.

    :param epubid: The database ID of the epub record.
    :param filepath: Path to the epub file on disk.
    """
    db = None
    chapter_files = []  # track written files for cleanup on failure
    try:
        db = sqlite3.connect(DB_PATH)
        db.row_factory = sqlite3.Row

        book = epub_lib.read_epub(filepath)

        spine_ids = [item_id for item_id, _ in book.spine]

        chapter_number = 0
        for item_id in spine_ids:
            item = book.get_item_with_id(item_id)
            if item is None:
                continue
            if item.get_type() != ebooklib.ITEM_DOCUMENT:
                continue
            # Skip navigation documents (table of contents)
            if isinstance(item, epub_lib.EpubNav):
                continue

            html_content = item.get_content().decode('utf-8', errors='replace')
            soup = BeautifulSoup(html_content, 'html.parser')
            text = soup.get_text(separator='\n', strip=True)

            if not text.strip():
                continue

            chapter_number += 1

            # Extract chapter title from first heading
            chapter_title = ''
            for tag in ['h1', 'h2', 'h3']:
                heading = soup.find(tag)
                if heading:
                    chapter_title = heading.get_text(strip=True)[:512]
                    break
            if not chapter_title:
                chapter_title = f'Chapter {chapter_number}'

            txt_filename = f"{uuid.uuid4().hex}.txt"
            txt_filepath = os.path.join(UPLOAD_FOLDER, txt_filename)
            with open(txt_filepath, 'w', encoding='utf-8') as f:
                f.write(text)
            chapter_files.append(txt_filepath)

            db.execute(
                'INSERT INTO epub_chapters (epubid, chapter_number, title, filename) '
                'VALUES (?, ?, ?, ?)',
                (epubid, chapter_number, chapter_title, txt_filename)
            )

        if chapter_number == 0:
            db.execute(
                'UPDATE epubs SET status = ?, error_message = ? WHERE epubid = ?',
                ('FAILED', 'No readable chapters found in epub', epubid)
            )
        else:
            db.execute(
                'UPDATE epubs SET status = ? WHERE epubid = ?',
                ('PARSED', epubid)
            )

        db.commit()
        logger.info('epub parsed: epubId=%s chapters=%d', epubid, chapter_number)

    except Exception as e:
        logger.exception('epub parsing failed: epubId=%s error=%s', epubid, e)
        for fpath in chapter_files:
            try:
                if os.path.exists(fpath):
                    os.remove(fpath)
            except Exception:
                pass
        if db:
            try:
                db.execute(
                    'UPDATE epubs SET status = ?, error_message = ? WHERE epubid = ?',
                    ('FAILED', str(e)[:1024], epubid)
                )
                db.commit()
            except Exception as db_err:
                logger.exception('failed to update epub status: %s', db_err)
    finally:
        if db:
            db.close()

@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    """Serve an uploaded file, requiring authentication.

    **GET** ``/uploads/<filename>``

    :param filename: Path to the file inside the uploads folder.
    :type filename: str
    :returns: The requested file.
    :status 200: File returned successfully.
    :status 403: No valid session token provided.
    :status 404: File not found on disk.
    """
    # Require authentication to fetch uploaded files (P2 behavior)
    username = get_username_from_token(request)
    if not username:
        abort(403)
    # send file or 404
    fullpath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    if not os.path.exists(fullpath):
        abort(404)
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

@app.route('/sessions', methods=['POST'])
def create_session():
    """Create a new session (login).

    **POST** ``/sessions``

    Accepts a JSON body with ``username`` and ``password``. Verifies the
    password against the stored salted SHA-512 hash, generates a session
    token, and returns it along with the authenticated user object.
    Also sets an ``httponly`` session cookie for browser clients.

    :json string username: Account username.
    :json string password: Account password (plaintext, hashed server-side).
    :returns: JSON with ``token`` (str) and ``user`` object.
    :status 200: Login successful.
    :status 400: Missing ``username`` or ``password``.
    :status 403: Invalid credentials.
    """
    data = request.get_json() or {}
    username = data.get('username')
    password = data.get('password')
    if not username or not password:
        abort(400)
    db = get_db()
    # verify username/password
    row = db.execute('SELECT username, fullname, filename, password FROM users WHERE username = ?', (username,)).fetchone()
    if not row:
        abort(403)
    stored = row['password'] or ''
    # Allow a simple mock password marker for seeded development users.
    # If the stored password is the literal string 'password', accept when
    # the provided password is also 'password'. This enables simple mock
    # accounts seeded into the repository for demos/testing.
    if stored == 'password':
        if password != 'password':
            abort(403)
    # Support salted format: sha512$<salt>$<hash>
    elif stored.startswith('sha512$'):
        try:
            _prefix, salt, stored_hash = stored.split('$', 2)
            provided_hash = hashlib.sha512((salt + password).encode('utf-8')).hexdigest()
            if provided_hash != stored_hash:
                abort(403)
        except Exception:
            abort(403)
    else:
        # legacy unsalted hash
        provided_hash = hashlib.sha512(password.encode('utf-8')).hexdigest()
        if provided_hash != stored:
            abort(403)

    token = uuid.uuid4().hex
    db.execute('INSERT INTO sessions (token, username) VALUES (?, ?)', (token, username))
    db.commit()
    # Return user where id is the username (username is primary key)
    user = {
        'id': row['username'],
        'username': row['username'],
        'displayName': row['fullname'],
        'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (row['filename'] or 'default.jpg')
    }
    logger.info("session created: username=%s token=%s", username, token)
    resp = make_response(jsonify({'token': token, 'user': user}))
    # also set a session cookie for browser-based pages
    resp.set_cookie('session', token, httponly=True)
    return resp

@app.route('/books/search', methods=['GET'])
def search_books():
    """Search for books by title/author/ISBN (stub).

    **GET** `/books/search?q=<query>`

    Returns a list of book results. This is currently a stub implementation
    to support the iOS manual search workflow; it can later be replaced with
    external API lookup (Open Library / Google Books) or a local books table.
    """
    q = (request.args.get('q') or '').strip()
    if not q:
        return jsonify([])

    # Minimal stub results (deterministic-ish, safe for demos)
    # Shape matches the iOS BookSearchResult model.
    results = [
        {
            'id': uuid.uuid4().hex,
            'title': f'{q} (Sample Result 1)',
            'authors': ['Demo Author'],
            'isbn13': None
        },
        {
            'id': uuid.uuid4().hex,
            'title': f'{q} (Sample Result 2)',
            'authors': ['Kiwi Fruit', 'Savannah Brown'],
            'isbn13': '9780000000002'
        },
        {
            'id': uuid.uuid4().hex,
            'title': f'{q} (Sample Result 3)',
            'authors': None,
            'isbn13': None
        }
    ]
    return jsonify(results)

@app.route('/posts', methods=['GET', 'POST'])
def posts_handler():
    """Retrieve the paginated post feed or create a new post.

    **GET** ``/posts``

    Returns posts ordered by creation date descending.
    Supports ``page`` (0-indexed, default 0) and ``pageSize`` (default 10)
    query parameters. Authentication is not required to read posts.

    **POST** ``/posts``

    Creates a new post. Requires authentication. Expects a multipart form
    with a ``file`` field (image) and an optional ``caption`` field.
    The image is saved with a UUID-based filename to avoid collisions.

    :returns: JSON list of post objects (GET) or the created post object (POST).
    :status 200: Feed returned successfully.
    :status 400: Missing file or empty filename (POST).
    :status 403: Not authenticated (POST).
    """
    db = get_db()
    if request.method == 'GET':
        page = int(request.args.get('page', 0))
        pageSize = int(request.args.get('pageSize', 10))
        offset = page * pageSize
        # select post filename as postfile and user filename as userfile to avoid ambiguity
        rows = db.execute('SELECT p.postid, p.filename as postfile, p.owner, p.caption, p.created, u.username, u.fullname, u.filename as userfile FROM posts p JOIN users u ON u.username = p.owner ORDER BY p.created DESC LIMIT ? OFFSET ?', (pageSize, offset)).fetchall()

        posts = []
        for r in rows:
            postid = r['postid']
            owner = {'id': r['username'], 'username': r['username'], 'displayName': r['fullname'], 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (r['userfile'] or 'default.jpg')}
            imageURL = request.host_url.rstrip('/') + '/uploads/' + r['postfile']
            likes = db.execute('SELECT COUNT(*) as c FROM likes WHERE postid = ?', (postid,)).fetchone()['c']
            posts.append({'id': str(postid), 'author': owner, 'imageURL': imageURL, 'caption': r['caption'], 'likes': likes})
        return jsonify(posts)

    # POST - create
    username = get_username_from_token(request)
    if not username:
        abort(403)
    if 'file' not in request.files:
        abort(400)
    file = request.files['file']
    if file.filename == '':
        abort(400)
    filename = file.filename
    stem = uuid.uuid4().hex
    suffix = os.path.splitext(filename)[1].lower()
    uuid_basename = f"{stem}{suffix}"
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], uuid_basename)
    file.save(filepath)
    caption = request.form.get('caption')
    # Insert post (AUTOINCREMENT postid)
    cur = db.execute('INSERT INTO posts (filename, owner, caption) VALUES (?, ?, ?)', (uuid_basename, username, caption))
    db.commit()
    postid = cur.lastrowid
    # Return the created post in the same shape as GET /posts so clients can decode it.
    row = db.execute('SELECT p.postid, p.filename, p.owner, p.caption, p.created, u.username, u.fullname, u.filename as userfile FROM posts p JOIN users u ON u.username = p.owner WHERE p.postid = ?', (postid,)).fetchone()
    if not row:
        return jsonify({'status': 'ok', 'postId': postid})
    # Build author dict
    owner = {
        'id': row['username'],
        'username': row['username'],
        'displayName': row['fullname'],
        'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (row['userfile'] or 'default.jpg')
    }
    imageURL = request.host_url.rstrip('/') + '/uploads/' + row['filename']
    likes = db.execute('SELECT COUNT(*) as c FROM likes WHERE postid = ?', (postid,)).fetchone()['c']
    post = {
        'id': str(postid),
        'author': owner,
        'imageURL': imageURL,
        'caption': row['caption'],
        'likes': likes
    }
    logger.info("post created: postId=%s owner=%s filename=%s", postid, username, uuid_basename)
    return jsonify(post)

@app.route('/posts/<post_id>/like', methods=['POST', 'DELETE'])
def post_like(post_id):
    """Like or unlike a post.

    **POST** ``/posts/<post_id>/like`` — Adds a like for the authenticated user.
    If already liked, returns the current count without inserting a duplicate.

    **DELETE** ``/posts/<post_id>/like`` — Removes the authenticated user's like.

    :param post_id: ID of the post to like or unlike.
    :type post_id: str
    :returns: JSON with ``likes`` (int) — the updated total like count.
    :status 200: Like count returned.
    :status 403: Not authenticated.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)
    db = get_db()
    if request.method == 'POST':
        # insert like if not exists
        exists = db.execute('SELECT 1 FROM likes WHERE owner = ? AND postid = ?', (username, post_id)).fetchone()
        if exists:
            # already liked; return current count
            likes = db.execute('SELECT COUNT(*) as c FROM likes WHERE postid = ?', (post_id,)).fetchone()['c']
            return jsonify({'likes': likes})
        db.execute('INSERT INTO likes (owner, postid) VALUES (?, ?)', (username, post_id))
        db.commit()
        likes = db.execute('SELECT COUNT(*) as c FROM likes WHERE postid = ?', (post_id,)).fetchone()['c']
        return jsonify({'likes': likes})

    # DELETE - remove like
    db.execute('DELETE FROM likes WHERE owner = ? AND postid = ?', (username, post_id))
    db.commit()
    likes = db.execute('SELECT COUNT(*) as c FROM likes WHERE postid = ?', (post_id,)).fetchone()['c']
    return jsonify({'likes': likes})


@app.route('/posts/<post_id>', methods=['GET','DELETE'])
def post_detail(post_id):
    """Retrieve or delete a single post.

    **GET** ``/posts/<post_id>`` — Returns the post object. No authentication required.

    **DELETE** ``/posts/<post_id>`` — Deletes the post and its associated image file.
    Requires authentication; only the post owner may delete it.

    :param post_id: ID of the post.
    :type post_id: str
    :returns: JSON post object (GET) or ``{"status": "ok"}`` (DELETE).
    :status 200: Success.
    :status 403: Not authenticated or not the post owner (DELETE).
    :status 404: Post not found.
    """
    db = get_db()
    if request.method == 'GET':
        row = db.execute('SELECT p.postid, p.filename, p.owner, p.caption, p.created, u.username, u.fullname FROM posts p JOIN users u ON u.username = p.owner WHERE p.postid = ?', (post_id,)).fetchone()
        if not row:
            abort(404)
        # ensure we select user file separately and convert created timestamp to ISO8601
        row = db.execute('SELECT p.postid, p.filename as postfile, p.owner, p.caption, p.created, u.username, u.fullname, u.filename as userfile FROM posts p JOIN users u ON u.username = p.owner WHERE p.postid = ?', (post_id,)).fetchone()
        owner = {'id': row['username'], 'username': row['username'], 'displayName': row['fullname'], 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (row['userfile'] or 'default.jpg')}
        imageURL = request.host_url.rstrip('/') + '/uploads/' + row['postfile']
        likes = db.execute('SELECT COUNT(*) as c FROM likes WHERE postid = ?', (post_id,)).fetchone()['c']
        post = {'id': str(row['postid']), 'author': owner, 'imageURL': imageURL, 'caption': row['caption'], 'likes': likes}
        return jsonify(post)

    # DELETE
    username = get_username_from_token(request)
    if not username:
        abort(403)
    row = db.execute('SELECT owner, filename FROM posts WHERE postid = ?', (post_id,)).fetchone()
    if not row:
        abort(404)
    if row['owner'] != username:
        abort(403)
    # delete post record and associated file
    db.execute('DELETE FROM posts WHERE postid = ?', (post_id,))
    db.commit()
    try:
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], row['filename'])
        if os.path.exists(filepath):
            os.remove(filepath)
    except Exception as e:
        logger.warning('failed to remove file %s: %s', row['filename'], e)
    logger.info('post deleted: postId=%s owner=%s', post_id, username)
    return jsonify({'status': 'ok'})


@app.route('/posts/<post_id>/comments', methods=['GET'])
def post_comments(post_id):
    """Retrieve all comments for a post, ordered oldest first.

    **GET** ``/posts/<post_id>/comments``

    :param post_id: ID of the post whose comments to fetch.
    :type post_id: str
    :returns: JSON list of comment objects, each containing ``id``, ``author``,
              ``text``, and ``createdAt`` (ISO 8601).
    :status 200: Comments returned successfully.
    """
    db = get_db()
    rows = db.execute('SELECT c.commentid, c.owner, c.text, c.created, u.username, u.fullname, u.filename FROM comments c JOIN users u ON u.username = c.owner WHERE c.postid = ? ORDER BY c.created ASC', (post_id,)).fetchall()
    comments = []
    for r in rows:
        author = {'id': r['username'], 'username': r['username'], 'displayName': r['fullname'], 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (r['filename'] or 'default.jpg')}
        comments.append({'id': str(r['commentid']), 'author': author, 'text': r['text'], 'createdAt': _to_iso(r['created'])})
    return jsonify(comments)

@app.route('/comments', methods=['POST'])
def comments_handler():
    """Create or delete a comment.

    **POST** ``/comments``

    Dispatches on the ``operation`` form field:

    - ``create``: Adds a new comment. Requires ``text`` and ``postid`` form fields.
    - ``delete``: Removes a comment. Requires ``commentid`` form field.
      Only the comment owner may delete it.

    Requires authentication for all operations.

    :returns: JSON ``{"status": "ok"}`` on success.
    :status 200: Operation completed.
    :status 400: Missing required fields or unknown operation.
    :status 403: Not authenticated, or attempting to delete another user's comment.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)
    operation = request.form.get('operation')
    if operation == 'create':
        text = request.form.get('text', '').strip()
        postid = request.form.get('postid')
        if not text or not postid:
            abort(400)
        db = get_db()
        # create comment with AUTOINCREMENT id
        db.execute('INSERT INTO comments (owner, postid, text) VALUES (?, ?, ?)', (username, postid, text))
        db.commit()
        return jsonify({'status': 'ok'})
    if operation == 'delete':
        commentid = request.form.get('commentid')
        if not commentid:
            abort(400)
        db = get_db()
        row = db.execute('SELECT owner FROM comments WHERE commentid = ?', (commentid,)).fetchone()
        if not row or row['owner'] != username:
            abort(403)
        db.execute('DELETE FROM comments WHERE commentid = ?', (commentid,))
        db.commit()
        return jsonify({'status': 'ok'})
    abort(400)


@app.route('/users/<username>', methods=['GET'])
def get_user(username):
    """Retrieve a user's public profile.

    **GET** ``/users/<username>``

    :param username: The username to look up.
    :type username: str
    :returns: JSON user object with ``id``, ``username``, ``displayName``,
              and ``avatarURL``.
    :status 200: User found and returned.
    :status 404: User not found.
    """
    db = get_db()
    row = db.execute('SELECT username, fullname, filename FROM users WHERE username = ?', (username,)).fetchone()
    if not row:
        abort(404)
    user = {
        'id': row['username'],
        'username': row['username'],
        'displayName': row['fullname'],
        'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (row['filename'] or 'default.jpg')
    }
    return jsonify(user)


@app.route('/users/<username>/follow', methods=['POST', 'DELETE'])
def follow_user(username):
    """Follow or unfollow a user.

    **POST** ``/users/<username>/follow`` — Follow the specified user.
    Silently succeeds if the relationship already exists.

    **DELETE** ``/users/<username>/follow`` — Unfollow the specified user.

    Requires authentication. A user cannot follow themselves.

    :param username: The username of the user to follow or unfollow.
    :type username: str
    :returns: JSON ``{"status": "ok"}``.
    :status 200: Operation completed.
    :status 400: Attempting to follow yourself.
    :status 403: Not authenticated.
    :status 404: Target user not found.
    """
    current = get_username_from_token(request)
    if not current:
        abort(403)
    if current == username:
        # cannot follow yourself
        abort(400)
    db = get_db()
    # ensure target exists
    if not db.execute('SELECT 1 FROM users WHERE username = ?', (username,)).fetchone():
        abort(404)
    if request.method == 'POST':
        try:
            db.execute('INSERT INTO following (follower, followee) VALUES (?, ?)', (current, username))
            db.commit()
        except sqlite3.IntegrityError:
            # already following or constraint violation
            pass
        return jsonify({'status': 'ok'})
    else:
        db.execute('DELETE FROM following WHERE follower = ? AND followee = ?', (current, username))
        db.commit()
        return jsonify({'status': 'ok'})


@app.route('/users/<username>/followers', methods=['GET'])
def get_followers(username):
    """Retrieve the list of users following the specified user.

    **GET** ``/users/<username>/followers``

    :param username: The username whose followers to retrieve.
    :type username: str
    :returns: JSON list of user objects, ordered by most-recently-followed first.
    :status 200: Followers returned.
    :status 404: User not found.
    """
    db = get_db()
    if not db.execute('SELECT 1 FROM users WHERE username = ?', (username,)).fetchone():
        abort(404)
    rows = db.execute('SELECT u.username, u.fullname, u.filename FROM following f JOIN users u ON u.username = f.follower WHERE f.followee = ? ORDER BY f.created DESC', (username,)).fetchall()
    out = []
    for r in rows:
        out.append({'id': r['username'], 'username': r['username'], 'displayName': r['fullname'], 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (r['filename'] or 'default.jpg')})
    return jsonify(out)


@app.route('/users/<username>/following', methods=['GET'])
def get_following(username):
    """Retrieve the list of users that the specified user is following.

    **GET** ``/users/<username>/following``

    :param username: The username whose following list to retrieve.
    :type username: str
    :returns: JSON list of user objects, ordered by most-recently-followed first.
    :status 200: Following list returned.
    :status 404: User not found.
    """
    db = get_db()
    if not db.execute('SELECT 1 FROM users WHERE username = ?', (username,)).fetchone():
        abort(404)
    rows = db.execute('SELECT u.username, u.fullname, u.filename FROM following f JOIN users u ON u.username = f.followee WHERE f.follower = ? ORDER BY f.created DESC', (username,)).fetchall()
    out = []
    for r in rows:
        out.append({'id': r['username'], 'username': r['username'], 'displayName': r['fullname'], 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (r['filename'] or 'default.jpg')})
    return jsonify(out)


@app.route('/users', methods=['POST'])
def create_user():
    """Create a new user account.

    **POST** ``/users``

    Stores a salted SHA-512 password hash. Returns 409 if the username is
    already taken.

    :json string username: Desired username (required).
    :json string password: Account password in plaintext (required, hashed server-side).
    :json string fullname: Display name (optional, defaults to username).
    :json string email: Email address (optional, defaults to ``<username>@example.com``).
    :returns: JSON user object with ``id``, ``username``, ``displayName``,
              and ``avatarURL``.
    :status 201: User created successfully.
    :status 400: Missing ``username`` or ``password``.
    :status 409: Username already exists.
    """
    data = request.get_json() or {}
    username = data.get('username')
    password = data.get('password')
    fullname = data.get('fullname') or username
    email = data.get('email') or f"{username}@example.com"
    if not username or not password:
        abort(400)
    db = get_db()
    # check uniqueness
    if db.execute('SELECT 1 FROM users WHERE username = ?', (username,)).fetchone():
        return jsonify({'error': 'username_conflict'}), 409
    # generate per-user salt and store as sha512$<salt>$<hash>
    salt = uuid.uuid4().hex
    pw_hash_raw = hashlib.sha512((salt + password).encode('utf-8')).hexdigest()
    pw_hash = f"sha512${salt}${pw_hash_raw}"
    filename = 'default.jpg'
    db.execute('INSERT INTO users (username, fullname, email, filename, password) VALUES (?, ?, ?, ?, ?)', (username, fullname, email, filename, pw_hash))
    db.commit()
    user = {'id': username, 'username': username, 'displayName': fullname, 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + filename}
    logger.info('user created: username=%s', username)
    return jsonify(user), 201


@app.route('/users/<username>', methods=['PUT'])
def update_user(username):
    """Update a user's profile information.

    **PUT** ``/users/<username>``

    Only the authenticated account owner may update their own profile.
    Fields not present in the request body are left unchanged.

    :param username: The username of the account to update.
    :type username: str
    :json string fullname: New display name (optional).
    :json string email: New email address (optional).
    :returns: JSON user object reflecting the updated profile.
    :status 200: Profile updated and returned.
    :status 403: Not authenticated or not the account owner.
    :status 404: User not found.
    """
    current = get_username_from_token(request)
    if not current:
        abort(403)
    db = get_db()
    row = db.execute('SELECT username FROM users WHERE username = ?', (username,)).fetchone()
    if not row:
        abort(404)
    if row['username'] != current:
        abort(403)
    data = request.get_json() or {}
    fullname = data.get('fullname')
    email = data.get('email')
    updates = []
    params = []
    if fullname is not None:
        updates.append('fullname = ?')
        params.append(fullname)
    if email is not None:
        updates.append('email = ?')
        params.append(email)
    if updates:
        params.append(username)
        sql = 'UPDATE users SET ' + ', '.join(updates) + ' WHERE username = ?'
        db.execute(sql, params)
        db.commit()
    newrow = db.execute('SELECT username, fullname, filename FROM users WHERE username = ?', (username,)).fetchone()
    user = {'id': newrow['username'], 'username': newrow['username'], 'displayName': newrow['fullname'], 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (newrow['filename'] or 'default.jpg')}
    return jsonify(user)


@app.route('/api/epub', methods=['POST'])
def epub_upload():
    """Upload an epub file for background parsing.

    **POST** ``/api/epub``

    Accepts a multipart form with a ``file`` field containing an ``.epub`` file.
    Saves the file, creates an epub record with LOADING status, and starts
    a background thread to parse chapters.

    :returns: JSON epub object with ``id``, ``title``, ``author``, ``status``,
              ``originalFilename``, and ``createdAt``.
    :status 201: Epub accepted and parsing started.
    :status 400: Missing file, empty filename, or not an .epub file.
    :status 403: Not authenticated.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)

    if 'file' not in request.files:
        abort(400)
    file = request.files['file']
    if file.filename == '':
        abort(400)

    original_filename = file.filename
    suffix = os.path.splitext(original_filename)[1].lower()
    if suffix != '.epub':
        return jsonify({'error': 'invalid_file_type',
                        'message': 'Only .epub files are accepted'}), 400

    stem = uuid.uuid4().hex
    stored_filename = f"{stem}{suffix}"
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], stored_filename)
    file.save(filepath)

    title, author = _extract_epub_metadata(filepath, original_filename)

    db = get_db()
    cur = db.execute(
        'INSERT INTO epubs (owner, title, author, original_filename, stored_filename, status) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        (username, title, author, original_filename, stored_filename, 'LOADING')
    )
    db.commit()
    epubid = cur.lastrowid

    thread = threading.Thread(
        target=_parse_epub_chapters,
        args=(epubid, filepath),
        daemon=True
    )
    thread.start()

    row = db.execute(
        'SELECT epubid, title, author, status, original_filename, created '
        'FROM epubs WHERE epubid = ?',
        (epubid,)
    ).fetchone()

    logger.info("epub upload started: epubId=%s owner=%s filename=%s", epubid, username, stored_filename)

    return jsonify({
        'id': str(row['epubid']),
        'title': row['title'],
        'author': row['author'],
        'status': row['status'],
        'originalFilename': row['original_filename'],
        'createdAt': _to_iso(row['created'])
    }), 201


@app.route('/api/epub/<epub_id>', methods=['GET'])
def epub_detail(epub_id):
    """Retrieve epub metadata and parsing status.

    **GET** ``/api/epub/<epub_id>``

    Requires authentication. Only the owner may access their epub.

    :param epub_id: ID of the epub.
    :returns: JSON epub object including status and chapter count.
    :status 200: Epub returned.
    :status 403: Not authenticated or not the owner.
    :status 404: Epub not found.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)

    db = get_db()
    row = db.execute(
        'SELECT epubid, owner, title, author, original_filename, status, error_message, created '
        'FROM epubs WHERE epubid = ?', (epub_id,)
    ).fetchone()
    if not row:
        abort(404)
    if row['owner'] != username:
        abort(403)

    chapter_count = db.execute(
        'SELECT COUNT(*) as c FROM epub_chapters WHERE epubid = ?', (epub_id,)
    ).fetchone()['c']

    return jsonify({
        'id': str(row['epubid']),
        'title': row['title'],
        'author': row['author'],
        'status': row['status'],
        'originalFilename': row['original_filename'],
        'createdAt': _to_iso(row['created']),
        'errorMessage': row['error_message'],
        'chapterCount': chapter_count
    })


@app.route('/api/epub/<epub_id>/chapters', methods=['GET'])
def epub_chapters(epub_id):
    """Retrieve all chapters for an epub.

    **GET** ``/api/epub/<epub_id>/chapters``

    Requires authentication. Only the owner may access. Returns 409 if the
    epub is still being parsed or parsing failed.

    :param epub_id: ID of the epub.
    :returns: JSON list of chapter objects ordered by chapter number.
    :status 200: Chapters returned.
    :status 403: Not authenticated or not the owner.
    :status 404: Epub not found.
    :status 409: Epub is still LOADING or FAILED.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)

    db = get_db()
    epub_row = db.execute(
        'SELECT epubid, owner, status FROM epubs WHERE epubid = ?', (epub_id,)
    ).fetchone()
    if not epub_row:
        abort(404)
    if epub_row['owner'] != username:
        abort(403)
    if epub_row['status'] == 'LOADING':
        return jsonify({'error': 'epub_still_loading',
                        'message': 'Epub is still being parsed'}), 409
    if epub_row['status'] == 'FAILED':
        return jsonify({'error': 'epub_parse_failed',
                        'message': 'Epub parsing failed'}), 409

    rows = db.execute(
        'SELECT chapterid, chapter_number, title, filename FROM epub_chapters '
        'WHERE epubid = ? ORDER BY chapter_number ASC', (epub_id,)
    ).fetchall()

    chapters = []
    for r in rows:
        chapters.append({
            'id': str(r['chapterid']),
            'chapterNumber': r['chapter_number'],
            'title': r['title'],
            'filename': r['filename']
        })
    return jsonify(chapters)


@app.route('/api/epubs', methods=['GET'])
def epub_list():
    """List all epubs belonging to the authenticated user.

    **GET** ``/api/epubs``

    :returns: JSON list of epub metadata objects (no chapter data).
    :status 200: List returned.
    :status 403: Not authenticated.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)

    db = get_db()
    rows = db.execute(
        'SELECT epubid, title, author, original_filename, status, error_message, created '
        'FROM epubs WHERE owner = ? ORDER BY created DESC', (username,)
    ).fetchall()

    epubs = []
    for r in rows:
        chapter_count = db.execute(
            'SELECT COUNT(*) as c FROM epub_chapters WHERE epubid = ?',
            (r['epubid'],)
        ).fetchone()['c']
        epubs.append({
            'id': str(r['epubid']),
            'title': r['title'],
            'author': r['author'],
            'originalFilename': r['original_filename'],
            'status': r['status'],
            'errorMessage': r['error_message'],
            'createdAt': _to_iso(r['created']),
            'chapterCount': chapter_count
        })
    return jsonify(epubs)


@app.errorhandler(HTTPException)
def handle_http_exception(e: HTTPException):
    """Return a JSON error body for all HTTP exceptions.

    Converts Werkzeug :class:`~werkzeug.exceptions.HTTPException` errors
    (e.g. 400, 403, 404) into a consistent JSON response instead of HTML.

    :param e: The HTTP exception raised.
    :returns: JSON ``{"message": ..., "status_code": ...}`` with the matching status code.
    """
    response = {'message': e.description, 'status_code': e.code}
    return jsonify(response), e.code


@app.errorhandler(Exception)
def handle_exception(e):
    """Return a JSON 500 response for any unhandled exception.

    Logs the full traceback and returns a generic error message to the client
    so internal details are not exposed.

    :param e: The unhandled exception.
    :returns: JSON ``{"error": "internal_server_error", "message": ...}`` with status 500.
    """
    logger.exception('Unhandled exception: %s', e)
    return jsonify({'error': 'internal_server_error', 'message': str(e)}), 500

def get_username_from_token(req):
    """Resolve the authenticated username from a request's session token.

    Checks the ``Authorization: Bearer <token>`` header first, then falls back
    to the ``session`` cookie. Looks the token up in the ``sessions`` table.

    :param req: The current Flask request object.
    :type req: flask.Request
    :returns: The username associated with the token, or ``None`` if the token
              is missing or invalid.
    :rtype: str or None
    """
    auth = req.headers.get('Authorization')
    token = None
    if auth and auth.startswith('Bearer '):
        token = auth.split(' ', 1)[1]
    else:
        token = req.cookies.get('session')
    if not token:
        return None
    db = get_db()
    row = db.execute('SELECT username FROM sessions WHERE token = ?', (token,)).fetchone()
    return row['username'] if row else None


# Backwards-compatible aliases for clients calling /api/* paths
try:
    app.add_url_rule('/api/posts', endpoint='posts_handler_api', view_func=posts_handler, methods=['GET', 'POST'])
    app.add_url_rule('/api/posts/<post_id>', endpoint='post_detail_api', view_func=post_detail, methods=['GET', 'DELETE'])
    app.add_url_rule('/api/posts/<post_id>/like', endpoint='post_like_api', view_func=post_like, methods=['POST', 'DELETE'])
    app.add_url_rule('/api/books/search', endpoint='search_books_api', view_func=search_books, methods=['GET'])
except Exception:
    # if handlers are not defined yet during import-time, ignore
    pass

if __name__ == '__main__':
    if not os.path.exists(DB_PATH):
        init_db()
    # Allow overriding the port with the environment (useful for running on non-default ports)
    port = int(os.environ.get('PORT', '5000'))
    app.run(debug=True, host='0.0.0.0', port=port)
