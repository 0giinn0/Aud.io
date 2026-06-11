-- aud.io Supabase Schema
-- Run this in your Supabase SQL editor after creating a project

-- 1. Profiles (extends auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  bio TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, username, display_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'preferred_username', 'user_' || substr(NEW.id::text, 1, 8)),
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 2. Playlists
CREATE TABLE playlists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  cover_url TEXT,
  is_public BOOLEAN DEFAULT true,
  track_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_playlists_user ON playlists(user_id);
CREATE INDEX idx_playlists_public ON playlists(is_public, created_at DESC);

-- 3. Playlist tracks
CREATE TABLE playlist_tracks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  playlist_id UUID NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  track_id TEXT NOT NULL,
  track_data JSONB NOT NULL,
  position INT NOT NULL,
  added_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(playlist_id, position)
);

CREATE INDEX idx_playlist_tracks_playlist ON playlist_tracks(playlist_id, position);

-- 4. Favorites (liked tracks)
CREATE TABLE favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  track_id TEXT NOT NULL,
  track_data JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, track_id)
);

CREATE INDEX idx_favorites_user ON favorites(user_id, created_at DESC);

-- 5. Listening history
CREATE TABLE listening_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  track_id TEXT NOT NULL,
  track_data JSONB NOT NULL,
  listened_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_history_user ON listening_history(user_id, listened_at DESC);

-- 6. Follows
CREATE TABLE follows (
  follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (follower_id, following_id),
  CHECK (follower_id != following_id)
);

CREATE INDEX idx_follows_follower ON follows(follower_id, created_at DESC);
CREATE INDEX idx_follows_following ON follows(following_id, created_at DESC);

-- 7. Comments on playlists
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  playlist_id UUID NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_comments_playlist ON comments(playlist_id, created_at DESC);

-- Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE playlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE playlist_tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE listening_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- Profiles: public read, own write
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Playlists: public read if public, owner can do all
CREATE POLICY "playlists_select" ON playlists FOR SELECT USING (is_public OR auth.uid() = user_id);
CREATE POLICY "playlists_insert" ON playlists FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "playlists_update" ON playlists FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "playlists_delete" ON playlists FOR DELETE USING (auth.uid() = user_id);

-- Playlist tracks: inherit from playlist
CREATE POLICY "tracks_select" ON playlist_tracks FOR SELECT USING (
  EXISTS (SELECT 1 FROM playlists WHERE id = playlist_id AND (is_public OR user_id = auth.uid()))
);
CREATE POLICY "tracks_insert" ON playlist_tracks FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM playlists WHERE id = playlist_id AND user_id = auth.uid())
);
CREATE POLICY "tracks_delete" ON playlist_tracks FOR DELETE USING (
  EXISTS (SELECT 1 FROM playlists WHERE id = playlist_id AND user_id = auth.uid())
);

-- Favorites: own
CREATE POLICY "favorites_select" ON favorites FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "favorites_insert" ON favorites FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "favorites_delete" ON favorites FOR DELETE USING (auth.uid() = user_id);

-- History: own
CREATE POLICY "history_select" ON listening_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "history_insert" ON listening_history FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Follows: public read, own write
CREATE POLICY "follows_select" ON follows FOR SELECT USING (true);
CREATE POLICY "follows_insert" ON follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "follows_delete" ON follows FOR DELETE USING (auth.uid() = follower_id);

-- Comments: public read, auth insert/delete own
CREATE POLICY "comments_select" ON comments FOR SELECT USING (true);
CREATE POLICY "comments_insert" ON comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "comments_delete" ON comments FOR DELETE USING (auth.uid() = user_id);

-- Helper functions for track count
CREATE OR REPLACE FUNCTION increment_playlist_track_count(pid UUID)
RETURNS void AS $$
  UPDATE playlists SET track_count = track_count + 1 WHERE id = pid;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION decrement_playlist_track_count(pid UUID)
RETURNS void AS $$
  UPDATE playlists SET track_count = GREATEST(track_count - 1, 0) WHERE id = pid;
$$ LANGUAGE sql;
