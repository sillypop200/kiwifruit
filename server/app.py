import os
import uuid
import hashlib
import sqlite3
import logging
from datetime import datetime, timezone
from flask import Flask, request, jsonify, g, abort, send_from_directory, make_response
from werkzeug.exceptions import HTTPException

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
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(DB_PATH)
        db.row_factory = sqlite3.Row
    return db

@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

def init_db():
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

@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
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
    # Support salted format: sha512$<salt>$<hash>
    if stored.startswith('sha512$'):
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

@app.route('/posts', methods=['GET', 'POST'])
def posts_handler():
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
    db = get_db()
    rows = db.execute('SELECT c.commentid, c.owner, c.text, c.created, u.username, u.fullname, u.filename FROM comments c JOIN users u ON u.username = c.owner WHERE c.postid = ? ORDER BY c.created ASC', (post_id,)).fetchall()
    comments = []
    for r in rows:
        author = {'id': r['username'], 'username': r['username'], 'displayName': r['fullname'], 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (r['filename'] or 'default.jpg')}
        comments.append({'id': str(r['commentid']), 'author': author, 'text': r['text'], 'createdAt': _to_iso(r['created'])})
    return jsonify(comments)

@app.route('/comments', methods=['POST'])
def comments_handler():
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
    # POST to follow, DELETE to unfollow; requires auth
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


@app.errorhandler(HTTPException)
def handle_http_exception(e: HTTPException):
    response = {'message': e.description, 'status_code': e.code}
    return jsonify(response), e.code


@app.errorhandler(Exception)
def handle_exception(e):
    logger.exception('Unhandled exception: %s', e)
    return jsonify({'error': 'internal_server_error', 'message': str(e)}), 500

def get_username_from_token(req):
    # Support either Authorization: Bearer <token> or cookie 'session'
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
except Exception:
    # if handlers are not defined yet during import-time, ignore
    pass

if __name__ == '__main__':
    if not os.path.exists(DB_PATH):
        init_db()
    # Allow overriding the port with the environment (useful for running on non-default ports)
    port = int(os.environ.get('PORT', '5000'))
    app.run(debug=True, host='0.0.0.0', port=port)
