-- Twitter/X style community tables

-- Posts table (like tweets)
CREATE TABLE IF NOT EXISTS community_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  attachments TEXT[] DEFAULT '{}',
  likes_count INTEGER DEFAULT 0,
  reposts_count INTEGER DEFAULT 0,
  replies_count INTEGER DEFAULT 0,
  views_count INTEGER DEFAULT 0,
  is_pinned BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Likes table (reactions)
CREATE TABLE IF NOT EXISTS post_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction_type TEXT DEFAULT 'like', -- like, love, laugh, fire, etc.
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id, reaction_type)
);

-- Reposts table (retweets)
CREATE TABLE IF NOT EXISTS post_reposts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- Replies table (comments as nested threads)
CREATE TABLE IF NOT EXISTS post_replies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  parent_reply_id UUID REFERENCES post_replies(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  attachments TEXT[] DEFAULT '{}',
  likes_count INTEGER DEFAULT 0,
  replies_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Reply likes
CREATE TABLE IF NOT EXISTS reply_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reply_id UUID NOT NULL REFERENCES post_replies(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  UNIQUE(reply_id, user_id)
);

-- Bookmarks (save posts)
CREATE TABLE IF NOT EXISTS post_bookmarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- Notifications for community interactions
CREATE TABLE IF NOT EXISTS community_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- like, reply, repost, mention
  actor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_community_posts_author ON community_posts(author_id);
CREATE INDEX IF NOT EXISTS idx_community_posts_created ON community_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_likes_post ON post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user ON post_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_reposts_post ON post_reposts(post_id);
CREATE INDEX IF NOT EXISTS idx_post_reposts_user ON post_reposts(user_id);
CREATE INDEX IF NOT EXISTS idx_post_replies_post ON post_replies(post_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_post_replies_parent ON post_replies(parent_reply_id);
CREATE INDEX IF NOT EXISTS idx_post_replies_author ON post_replies(author_id);
CREATE INDEX IF NOT EXISTS idx_reply_likes_reply ON reply_likes(reply_id);
CREATE INDEX IF NOT EXISTS idx_reply_likes_user ON reply_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_bookmarks_user ON post_bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_community_notifications_user ON community_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_community_notifications_unread ON community_notifications(user_id, is_read);

-- Enable RLS
ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_reposts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE reply_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "community_posts_select_all" ON community_posts FOR SELECT USING (true);
CREATE POLICY "community_posts_insert_own" ON community_posts FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "community_posts_update_own" ON community_posts FOR UPDATE USING (auth.uid() = author_id);
CREATE POLICY "community_posts_delete_own" ON community_posts FOR DELETE USING (auth.uid() = author_id);

CREATE POLICY "post_likes_select_all" ON post_likes FOR SELECT USING (true);
CREATE POLICY "post_likes_insert_own" ON post_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "post_likes_delete_own" ON post_likes FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "post_reposts_select_all" ON post_reposts FOR SELECT USING (true);
CREATE POLICY "post_reposts_insert_own" ON post_reposts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "post_reposts_delete_own" ON post_reposts FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "post_replies_select_all" ON post_replies FOR SELECT USING (true);
CREATE POLICY "post_replies_insert_own" ON post_replies FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "post_replies_update_own" ON post_replies FOR UPDATE USING (auth.uid() = author_id);
CREATE POLICY "post_replies_delete_own" ON post_replies FOR DELETE USING (auth.uid() = author_id);

CREATE POLICY "reply_likes_select_all" ON reply_likes FOR SELECT USING (true);
CREATE POLICY "reply_likes_insert_own" ON reply_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "reply_likes_delete_own" ON reply_likes FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "post_bookmarks_select_own" ON post_bookmarks FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "post_bookmarks_insert_own" ON post_bookmarks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "post_bookmarks_delete_own" ON post_bookmarks FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "community_notifications_select_own" ON community_notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "community_notifications_insert_system" ON community_notifications FOR INSERT WITH CHECK (true);