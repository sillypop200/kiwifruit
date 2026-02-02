import os
import uuid
import sqlite3
import logging
from datetime import datetime, timezone
from flask import Flask, request, jsonify, g, abort, send_from_directory

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

@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

@app.route('/sessions', methods=['POST'])
def create_session():
    data = request.get_json() or {}
    username = data.get('username')
    if not username:
        abort(400)
    token = uuid.uuid4().hex
    db = get_db()
    # create user if not exists with placeholder fields
    cur = db.execute('SELECT username FROM users WHERE username = ?', (username,))
    if not cur.fetchone():
        # Use standard UUID string format for user IDs so clients can parse as UUID
        db.execute('INSERT INTO users (userid, username, fullname, email, filename, password) VALUES (?, ?, ?, ?, ?, ?)',
                   (str(uuid.uuid4()), username, username, f'{username}@example.com', 'default.jpg', ''))
        db.commit()
    db.execute('INSERT INTO sessions (token, username) VALUES (?, ?)', (token, username))
    db.commit()
    # Return token and user object as generated from users table
    cur = db.execute('SELECT userid, username, fullname, filename FROM users WHERE username = ?', (username,)).fetchone()
    userid = cur['userid']
    user = {
        'id': userid,
        'username': cur['username'],
        'displayName': cur['fullname'],
        'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (cur['filename'] or 'default.jpg')
    }
    logger.info("session created: username=%s token=%s userId=%s", username, token, userid)
    return jsonify({'token': token, 'user': user})

@app.route('/posts', methods=['GET', 'POST'])
def posts_handler():
    db = get_db()
    if request.method == 'GET':
        page = int(request.args.get('page', 0))
        pageSize = int(request.args.get('pageSize', 10))
        offset = page * pageSize
        # select post filename as postfile and user filename as userfile to avoid ambiguity
        rows = db.execute('SELECT p.postid, p.filename as postfile, p.owner, p.caption, p.created, u.userid, u.username, u.fullname, u.filename as userfile FROM posts p JOIN users u ON u.username = p.owner ORDER BY p.created DESC LIMIT ? OFFSET ?', (pageSize, offset)).fetchall()
    def _to_iso(ts):
        # ts is a SQLite DATETIME like 'YYYY-MM-DD HH:MM:SS' or already ISO; return ISO8601
        if ts is None:
            return None
        try:
            # Try parsing common SQLite format
            dt = datetime.strptime(ts, '%Y-%m-%d %H:%M:%S')
            return dt.replace(tzinfo=timezone.utc).isoformat()
        except Exception:
            # If it's already ISO or another format, return as-is
            return ts

        posts = []
        for r in rows:
            postid = r['postid']
            owner = {'id': r['userid'], 'username': r['username'], 'displayName': r['fullname'], 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (r['userfile'] or 'default.jpg')}
            imageURL = request.host_url.rstrip('/') + '/uploads/' + r['postfile']
            likes = db.execute('SELECT COUNT(*) as c FROM likes WHERE postid = ?', (postid,)).fetchone()['c']
            # convert created timestamp to ISO8601 so the Swift client can decode with .iso8601
            created = r['created']
            try:
                from datetime import datetime
                created = datetime.strptime(created, '%Y-%m-%d %H:%M:%S').isoformat()
            except Exception:
                pass
            posts.append({'id': str(postid), 'author': owner, 'imageURL': imageURL, 'caption': r['caption'], 'likes': likes, 'createdAt': created})
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
    # create post id as standard UUID string
    postid = str(uuid.uuid4())
    db.execute('INSERT INTO posts (postid, owner, filename, caption) VALUES (?, ?, ?, ?)', (postid, username, uuid_basename, caption))
    db.commit()
    # Return the created post in the same shape as GET /posts so clients can decode it.
    row = db.execute('SELECT p.postid, p.filename, p.owner, p.caption, p.created, u.userid, u.username, u.fullname, u.filename as userfile FROM posts p JOIN users u ON u.username = p.owner WHERE p.postid = ?', (postid,)).fetchone()
    if not row:
        return jsonify({'status': 'ok', 'postId': postid})
    # Build author dict
    owner = {
        'id': row['userid'],
        'username': row['username'],
        'displayName': row['fullname'],
        'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (row['userfile'] or 'default.jpg')
    }
    imageURL = request.host_url.rstrip('/') + '/uploads/' + row['filename']
    likes = db.execute('SELECT COUNT(*) as c FROM likes WHERE postid = ?', (postid,)).fetchone()['c']
    created = row['created']
    # Convert SQLite timestamp to ISO8601 for client decoding
    try:
        from datetime import datetime
        created = datetime.strptime(created, '%Y-%m-%d %H:%M:%S').isoformat()
    except Exception:
        # leave as-is if parsing fails
        pass
    post = {
        'id': str(postid),
        'author': owner,
        'imageURL': imageURL,
        'caption': row['caption'],
        'likes': likes,
        'createdAt': created
    }
    logger.info("post created: postId=%s owner=%s filename=%s", postid, username, uuid_basename)
    return jsonify(post)

@app.route('/posts/<post_id>/like', methods=['POST', 'DELETE'])
def post_like(post_id):
    username = get_username_from_token(request)
    if not username:
        abort(403)
    db = get_db()
    like_exists = db.execute('SELECT 1 FROM likes WHERE owner = ? AND postid = ?', (username, post_id)).fetchone()
    if request.method == 'POST':
        row = db.execute('SELECT p.postid, p.filename as postfile, p.owner, p.caption, p.created, u.userid, u.username, u.fullname, u.filename as userfile FROM posts p JOIN users u ON u.username = p.owner WHERE p.postid = ?', (post_id,)).fetchone()
        if not row:
            abort(404)
        owner = {'id': row['userid'], 'username': row['username'], 'displayName': row['fullname'], 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (row['userfile'] or 'default.jpg')}
        imageURL = request.host_url.rstrip('/') + '/uploads/' + row['postfile']
        likes = db.execute('SELECT COUNT(*) as c FROM likes WHERE postid = ?', (post_id,)).fetchone()['c']
        created = row['created']
        try:
            from datetime import datetime
            created = datetime.strptime(created, '%Y-%m-%d %H:%M:%S').isoformat()
        except Exception:
            pass
        post = {'id': str(row['postid']), 'author': owner, 'imageURL': imageURL, 'caption': row['caption'], 'likes': likes, 'createdAt': created}
        return jsonify(post)
        db.execute('DELETE FROM likes WHERE owner = ? AND postid = ?', (username, post_id))
        db.commit()
    likes = db.execute('SELECT COUNT(*) as c FROM likes WHERE postid = ?', (post_id,)).fetchone()['c']
    return jsonify({'likes': likes})


@app.route('/posts/<post_id>', methods=['GET','DELETE'])
def post_detail(post_id):
    db = get_db()
    if request.method == 'GET':
        row = db.execute('SELECT p.postid, p.filename, p.owner, p.caption, p.created, u.userid, u.username, u.fullname FROM posts p JOIN users u ON u.username = p.owner WHERE p.postid = ?', (post_id,)).fetchone()
        if not row:
            abort(404)
        # ensure we select user file separately and convert created timestamp to ISO8601
        row = db.execute('SELECT p.postid, p.filename as postfile, p.owner, p.caption, p.created, u.userid, u.username, u.fullname, u.filename as userfile FROM posts p JOIN users u ON u.username = p.owner WHERE p.postid = ?', (post_id,)).fetchone()
        owner = {'id': row['userid'], 'username': row['username'], 'displayName': row['fullname'], 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (row['userfile'] or 'default.jpg')}
        imageURL = request.host_url.rstrip('/') + '/uploads/' + row['postfile']
        likes = db.execute('SELECT COUNT(*) as c FROM likes WHERE postid = ?', (post_id,)).fetchone()['c']
        created = row['created']
        try:
            from datetime import datetime
            created = datetime.strptime(created, '%Y-%m-%d %H:%M:%S').isoformat()
        except Exception:
            pass
        post = {'id': str(row['postid']), 'author': owner, 'imageURL': imageURL, 'caption': row['caption'], 'likes': likes, 'createdAt': created}
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
    db.execute('DELETE FROM likes WHERE postid = ?', (post_id,))
    db.execute('DELETE FROM comments WHERE postid = ?', (post_id,))
    db.commit()
    try:
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], row['filename'])
        if os.path.exists(filepath):
            os.remove(filepath)
    except Exception as e:
        logger.warning('failed to remove file %s: %s', row['filename'], e)
    logger.info('post deleted: postId=%s owner=%s', post_id, username)
    return jsonify({'status': 'ok'})

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
        # create comment id as UUID string
        db.execute('INSERT INTO comments (commentid, owner, postid, text) VALUES (?, ?, ?, ?)', (str(uuid.uuid4()), username, postid, text))
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


@app.route('/users/<user_id>', methods=['GET'])
def get_user(user_id):
    db = get_db()
    row = db.execute('SELECT userid, username, fullname, filename FROM users WHERE userid = ?', (user_id,)).fetchone()
    if not row:
        abort(404)
    user = {
        'id': row['userid'],
        'username': row['username'],
        'displayName': row['fullname'],
        'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (row['filename'] or 'default.jpg')
    }
    return jsonify(user)

def get_username_from_token(req):
    auth = req.headers.get('Authorization')
    if not auth or not auth.startswith('Bearer '):
        return None
    token = auth.split(' ', 1)[1]
    db = get_db()
    row = db.execute('SELECT username FROM sessions WHERE token = ?', (token,)).fetchone()
    return row['username'] if row else None

if __name__ == '__main__':
    if not os.path.exists(DB_PATH):
        init_db()
    # Allow overriding the port with the environment (useful for running on non-default ports)
    port = int(os.environ.get('PORT', '5000'))
    app.run(debug=True, host='0.0.0.0', port=port)
