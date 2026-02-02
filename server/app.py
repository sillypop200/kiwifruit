import os
import uuid
import sqlite3
from flask import Flask, request, jsonify, g, abort, send_from_directory

BASE_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(BASE_DIR, 'kiwifruit.db')
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

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
        db.execute('INSERT INTO users (userid, username, fullname, email, filename, password) VALUES (?, ?, ?, ?, ?, ?)',
                   (uuid.uuid4().hex, username, username, f'{username}@example.com', 'default.jpg', ''))
        db.commit()
    db.execute('INSERT INTO sessions (token, username) VALUES (?, ?)', (token, username))
    db.commit()
    # Return token and userId as generated uuid from users table
    cur = db.execute('SELECT userid FROM users WHERE username = ?', (username,)).fetchone()
    userid = cur['userid']
    return jsonify({'token': token, 'userId': userid})

@app.route('/posts', methods=['GET', 'POST'])
def posts_handler():
    db = get_db()
    if request.method == 'GET':
        page = int(request.args.get('page', 0))
        pageSize = int(request.args.get('pageSize', 10))
        offset = page * pageSize
        rows = db.execute('SELECT p.postid, p.filename, p.owner, p.caption, p.created, u.userid, u.username, u.fullname FROM posts p JOIN users u ON u.username = p.owner ORDER BY p.created DESC LIMIT ? OFFSET ?', (pageSize, offset)).fetchall()
        posts = []
        for r in rows:
            postid = r['postid']
            owner = {'id': r['userid'], 'username': r['username'], 'displayName': r['fullname'], 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + r['filename']}
            imageURL = request.host_url.rstrip('/') + '/uploads/' + r['filename']
            likes = db.execute('SELECT COUNT(*) as c FROM likes WHERE postid = ?', (postid,)).fetchone()['c']
            posts.append({'id': str(postid), 'author': owner, 'imageURL': imageURL, 'caption': r['caption'], 'likes': likes, 'createdAt': r['created']})
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
    db.execute('INSERT INTO posts (owner, filename, caption) VALUES (?, ?, ?)', (username, uuid_basename, caption))
    db.commit()
    return jsonify({'status': 'ok'})

@app.route('/posts/<int:post_id>/like', methods=['POST', 'DELETE'])
def post_like(post_id):
    username = get_username_from_token(request)
    if not username:
        abort(403)
    db = get_db()
    like_exists = db.execute('SELECT 1 FROM likes WHERE owner = ? AND postid = ?', (username, post_id)).fetchone()
    if request.method == 'POST':
        if like_exists:
            abort(409)
        db.execute('INSERT INTO likes (owner, postid) VALUES (?, ?)', (username, post_id))
        db.commit()
    else:
        if not like_exists:
            abort(409)
        db.execute('DELETE FROM likes WHERE owner = ? AND postid = ?', (username, post_id))
        db.commit()
    likes = db.execute('SELECT COUNT(*) as c FROM likes WHERE postid = ?', (post_id,)).fetchone()['c']
    return jsonify({'likes': likes})

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
    app.run(debug=True, host='0.0.0.0', port=5000)
