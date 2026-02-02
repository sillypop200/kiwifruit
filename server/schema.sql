PRAGMA foreign_keys = ON;

-- Users table (username is primary key)
CREATE TABLE users (
    username TEXT PRIMARY KEY CHECK (LENGTH(username) <= 20),
    fullname TEXT NOT NULL CHECK (LENGTH(fullname) <= 40),
    email TEXT NOT NULL CHECK (LENGTH(email) <= 40),
    filename TEXT NOT NULL CHECK (LENGTH(filename) <= 64),
    password TEXT NOT NULL CHECK (LENGTH(password) <= 512),
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Posts table with AUTOINCREMENT integer primary key
CREATE TABLE posts (
    postid INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT NOT NULL CHECK (LENGTH(filename) <= 64),
    owner TEXT NOT NULL CHECK (LENGTH(owner) <= 20),
    caption TEXT,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner) REFERENCES users (username) ON DELETE CASCADE
);

-- Following table (follower / followee)
CREATE TABLE following (
    follower TEXT NOT NULL CHECK (LENGTH(follower) <= 20),
    followee TEXT NOT NULL CHECK (LENGTH(followee) <= 20),
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (follower, followee),
    FOREIGN KEY (follower) REFERENCES users (username) ON DELETE CASCADE,
    FOREIGN KEY (followee) REFERENCES users (username) ON DELETE CASCADE
);

-- Comments table with AUTOINCREMENT integer primary key
CREATE TABLE comments (
    commentid INTEGER PRIMARY KEY AUTOINCREMENT,
    owner TEXT NOT NULL CHECK (LENGTH(owner) <= 20),
    postid INTEGER NOT NULL,
    text TEXT NOT NULL CHECK (LENGTH(text) <= 1024),
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner) REFERENCES users (username) ON DELETE CASCADE,
    FOREIGN KEY (postid) REFERENCES posts (postid) ON DELETE CASCADE
);

-- Likes table with AUTOINCREMENT integer primary key; enforce one-like-per-user-per-post
CREATE TABLE likes (
    likeid INTEGER PRIMARY KEY AUTOINCREMENT,
    owner TEXT NOT NULL CHECK (LENGTH(owner) <= 20),
    postid INTEGER NOT NULL,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner) REFERENCES users (username) ON DELETE CASCADE,
    FOREIGN KEY (postid) REFERENCES posts (postid) ON DELETE CASCADE,
    UNIQUE (owner, postid)
);

-- Sessions table for token mapping (simple session storage)
CREATE TABLE sessions (
    token TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (username) REFERENCES users (username) ON DELETE CASCADE
);
