#!/usr/bin/env bash
# Reset the SQLite DB and uploads folder to a minimal seeded state
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
DB="$ROOT/kiwifruit.db"
SCHEMA="$ROOT/schema.sql"
UPLOADS="$ROOT/uploads"

echo "Stopping any running server... (you may need to stop it manually)"

# Remove DB and recreate
if [ -f "$DB" ]; then
  echo "Removing existing DB: $DB"
  rm -f "$DB"
fi

echo "Creating fresh DB from schema"
sqlite3 "$DB" < "$SCHEMA"

# Clean uploads and seed with default images
if [ -d "$UPLOADS" ]; then
  echo "Cleaning uploads folder: $UPLOADS"
  rm -rf "$UPLOADS"
fi
mkdir -p "$UPLOADS"

# Seed only default avatar and a couple of production-like photos
# Use small placeholder images generated via data URLs to avoid external deps
cat > "$UPLOADS/default.jpg" <<'EOF'

# (placeholder) You can replace these files with actual production images.
EOF

# Create a tiny text file to act as an uploaded file (server accepts any file type)
echo "placeholder image" > "$UPLOADS/prod_placeholder_1.jpg"
echo "placeholder image" > "$UPLOADS/prod_placeholder_2.jpg"

# Seed a sample user and a couple posts referencing the placeholder images
python3 - <<PY
import sqlite3
conn = sqlite3.connect('$DB')
cur = conn.cursor()

# Insert sample users
cur.execute("INSERT INTO users (username, fullname, email, filename, password) VALUES (?, ?, ?, ?, ?)", ('prod_user', 'Prod User', 'prod@example.com', 'default.jpg', ''))
cur.execute("INSERT INTO users (username, fullname, email, filename, password) VALUES (?, ?, ?, ?, ?)", ('alice', 'Alice Example', 'alice@example.com', 'default.jpg', ''))

# Insert a couple posts for prod_user
cur.execute("INSERT INTO posts (filename, owner, caption, created) VALUES (?, ?, ?, datetime('now'))", ('prod_placeholder_1.jpg', 'prod_user', 'Welcome to KiwiFruit!'))
cur.execute("INSERT INTO posts (filename, owner, caption, created) VALUES (?, ?, ?, datetime('now'))", ('prod_placeholder_2.jpg', 'prod_user', 'Second production photo'))

conn.commit()
print('Seeded users: prod_user, alice')
cur.execute('SELECT postid, filename, owner FROM posts')
rows = cur.fetchall()
for r in rows:
  print('Seeded post', r[0], r[1], 'owner=', r[2])
conn.close()
PY

echo "Reset complete. Start the server with: PORT=5001 python3 app.py"
