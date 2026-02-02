PRAGMA foreign_keys = ON;

-- Create users table
CREATE TABLE users (
    userid TEXT PRIMARY KEY,
    username TEXT NOT NULL UNIQUE CHECK (LENGTH(username) <= 20),
    fullname TEXT NOT NULL CHECK (LENGTH(fullname) <= 40),
    email TEXT NOT NULL CHECK (LENGTH(email) <= 40),
    filename TEXT NOT NULL CHECK (LENGTH(filename) <= 64),
    password TEXT NOT NULL CHECK (LENGTH(password) <= 256),
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create posts table (use UUID strings for IDs)
CREATE TABLE posts (
    postid TEXT PRIMARY KEY,
    filename TEXT NOT NULL CHECK (LENGTH(filename) <= 64),
    owner TEXT NOT NULL CHECK (LENGTH(owner) <= 20),
    caption TEXT,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner) REFERENCES users (username) ON DELETE CASCADE
);

-- Create following table
CREATE TABLE following (
    username1 TEXT NOT NULL CHECK (LENGTH(username1) <= 20),
    username2 TEXT NOT NULL CHECK (LENGTH(username2) <= 20),
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (username1, username2),
    FOREIGN KEY (username1) REFERENCES users (username) ON DELETE CASCADE,
    FOREIGN KEY (username2) REFERENCES users (username) ON DELETE CASCADE
);

-- Create comments table (use UUID strings for IDs)
CREATE TABLE comments (
    commentid TEXT PRIMARY KEY,
    owner TEXT NOT NULL CHECK (LENGTH(owner) <= 20),
    postid TEXT NOT NULL,
    text TEXT NOT NULL CHECK (LENGTH(text) <= 1024),
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner) REFERENCES users (username) ON DELETE CASCADE,
    FOREIGN KEY (postid) REFERENCES posts (postid) ON DELETE CASCADE
);

-- Create likes table (use UUID strings for IDs)
CREATE TABLE likes (
    likeid TEXT PRIMARY KEY,
    owner TEXT NOT NULL CHECK (LENGTH(owner) <= 20),
    postid TEXT NOT NULL,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner) REFERENCES users (username) ON DELETE CASCADE,
    FOREIGN KEY (postid) REFERENCES posts (postid) ON DELETE CASCADE
);

-- Sessions table for token mapping
CREATE TABLE sessions (
    token TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
