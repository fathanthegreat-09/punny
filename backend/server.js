require('dotenv').config();
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const db = require('./database');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Ensure upload & data directories exist
const uploadDir = path.join(__dirname, 'uploads');
const dataDir = path.join(__dirname, 'data');
const postsFilePath = path.join(dataDir, 'posts.json');

if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

// Serve uploaded static files
app.use('/uploads', express.static(uploadDir));

// Multer storage configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    const uniqueSuffix = Date.now() + '-' + crypto.randomBytes(4).toString('hex');
    cb(null, `pin-${uniqueSuffix}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB limit
  fileFilter: (req, file, cb) => {
    const allowed = /jpeg|jpg|png|gif|webp|mp4|webm|mov|mkv/;
    const extName = allowed.test(path.extname(file.originalname).toLowerCase());
    const mimeType = allowed.test(file.mimetype);
    if (extName || mimeType) {
      return cb(null, true);
    }
    cb(new Error('File format not supported!'));
  }
});

// Seed data generator
function getInitialSeedPosts() {
  return [
    {
      id: 'pin-1',
      title: 'Neon Tokyo Aesthetic',
      imageUrl: 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=800&q=80',
      imageUrls: ['https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=800&q=80'],
      author: 'Fathan',
      likes: ['user1', 'user2'],
      likeCount: 2,
      createdAt: new Date(Date.now() - 1000 * 60 * 60 * 24).toISOString()
    },
    {
      id: 'pin-2',
      title: 'Minimalist Workspace Setup',
      imageUrl: 'https://images.unsplash.com/photo-1499750310107-5fef28a66643?auto=format&fit=crop&w=800&q=80',
      imageUrls: ['https://images.unsplash.com/photo-1499750310107-5fef28a66643?auto=format&fit=crop&w=800&q=80'],
      author: 'Fathan',
      likes: ['user1'],
      likeCount: 1,
      createdAt: new Date(Date.now() - 1000 * 60 * 60 * 18).toISOString()
    },
    {
      id: 'pin-3',
      title: 'Mountain Sunset In Alps',
      imageUrl: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=800&q=80',
      imageUrls: ['https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=800&q=80'],
      author: 'Arona',
      likes: ['user3', 'user4', 'user5'],
      likeCount: 3,
      createdAt: new Date(Date.now() - 1000 * 60 * 60 * 12).toISOString()
    },
    {
      id: 'pin-4',
      title: 'Matcha Latte Art & Cafe Vibes',
      imageUrl: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?auto=format&fit=crop&w=800&q=80',
      imageUrls: ['https://images.unsplash.com/photo-1536256263959-770b48d82b0a?auto=format&fit=crop&w=800&q=80'],
      author: 'Yuuka',
      likes: ['user2', 'user6'],
      likeCount: 2,
      createdAt: new Date(Date.now() - 1000 * 60 * 60 * 6).toISOString()
    },
    {
      id: 'pin-5',
      title: 'Cozy Reading Nook & Plants',
      imageUrl: 'https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=800&q=80',
      imageUrls: ['https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=800&q=80'],
      author: 'Fathan',
      likes: ['user1', 'user3', 'user4', 'user7'],
      likeCount: 4,
      createdAt: new Date(Date.now() - 1000 * 60 * 60 * 2).toISOString()
    },
    {
      id: 'pin-6',
      title: 'Cyberpunk City Street Lights',
      imageUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=800&q=80',
      imageUrls: ['https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=800&q=80'],
      author: 'Sensei',
      likes: ['user1'],
      likeCount: 1,
      createdAt: new Date(Date.now() - 1000 * 60 * 30).toISOString()
    }
  ];
}

// Initial seed helper for Aiven Database (populates default posts if database is empty)
async function seedInitialDatabaseIfEmpty() {
  try {
    const [rows] = await db.query('SELECT COUNT(*) as count FROM posts');
    if (rows[0].count === 0) {
      let initialPosts = [];
      if (fs.existsSync(postsFilePath)) {
        try {
          const fileData = fs.readFileSync(postsFilePath, 'utf-8');
          initialPosts = JSON.parse(fileData);
        } catch (_) {}
      }
      if (!initialPosts.length) {
        initialPosts = getInitialSeedPosts();
      }

      for (const p of initialPosts) {
        await db.query(
          `INSERT INTO posts (id, title, imageUrl, imageUrls, videoUrl, author, likes, likeCount, description, category, link, comments, createdAt)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            p.id,
            p.title || 'Untitled',
            p.imageUrl || '',
            JSON.stringify(p.imageUrls || (p.imageUrl ? [p.imageUrl] : [])),
            p.videoUrl || null,
            p.author || 'Anonymous',
            JSON.stringify(p.likes || []),
            Array.isArray(p.likes) ? p.likes.length : (p.likeCount || 0),
            p.description || null,
            p.category || 'Aesthetic',
            p.link || null,
            JSON.stringify(p.comments || []),
            p.createdAt ? new Date(p.createdAt) : new Date()
          ]
        );
      }
      console.log(`[Aiven DB] Successfully seeded ${initialPosts.length} initial posts!`);
    }
  } catch (err) {
    console.error('[Aiven DB] Error checking/seeding posts table:', err.message);
  }
}

// Run initial seed check
seedInitialDatabaseIfEmpty();

// Helper to format post from DB row to Flutter API expected format
function formatPostResponse(post, req) {
  const host = req.get('host') || `localhost:${PORT}`;
  const protocol = req.protocol || 'http';

  // Parse JSON columns safely if they come as string
  const parseJsonField = (val, defaultVal) => {
    if (!val) return defaultVal;
    if (typeof val === 'string') {
      try {
        return JSON.parse(val);
      } catch (_) {
        return defaultVal;
      }
    }
    return val;
  };

  const parsedImageUrls = parseJsonField(post.imageUrls, []);
  const parsedLikes = parseJsonField(post.likes, []);
  const parsedComments = parseJsonField(post.comments, []);

  let formattedImageUrl = post.imageUrl || '';
  if (formattedImageUrl.startsWith('/uploads/')) {
    formattedImageUrl = `${protocol}://${host}${formattedImageUrl}`;
  }

  const formattedImageUrls = (parsedImageUrls.length > 0 ? parsedImageUrls : [formattedImageUrl]).map(url => {
    if (typeof url === 'string' && url.startsWith('/uploads/')) {
      return `${protocol}://${host}${url}`;
    }
    return url;
  });

  return {
    id: String(post.id),
    title: post.title,
    imageUrl: formattedImageUrl,
    imageUrls: formattedImageUrls,
    videoUrl: post.videoUrl || null,
    author: post.author,
    likes: parsedLikes,
    likeCount: parsedLikes.length,
    description: post.description || null,
    category: post.category || 'Aesthetic',
    link: post.link || null,
    comments: parsedComments,
    createdAt: post.createdAt ? new Date(post.createdAt).toISOString() : new Date().toISOString()
  };
}

// ======================== ROUTES ========================

// 1. Health Check
app.get('/api/health', async (req, res) => {
  try {
    await db.query('SELECT 1');
    res.json({
      status: 'ok',
      database: 'connected (Aiven MySQL)',
      timestamp: new Date().toISOString()
    });
  } catch (err) {
    res.status(500).json({
      status: 'error',
      database: 'disconnected',
      error: err.message
    });
  }
});

// 2. GET all posts
app.get('/api/posts', async (req, res) => {
  try {
    const { author, search } = req.query;
    let query = 'SELECT * FROM posts';
    const params = [];
    const conditions = [];

    if (author) {
      conditions.push('LOWER(author) = LOWER(?)');
      params.push(author);
    }

    if (search) {
      conditions.push('LOWER(title) LIKE LOWER(?)');
      params.push(`%${search}%`);
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }

    query += ' ORDER BY createdAt DESC';

    const [rows] = await db.query(query, params);
    const responsePosts = rows.map(p => formatPostResponse(p, req));

    res.json({
      success: true,
      total: responsePosts.length,
      data: responsePosts
    });
  } catch (err) {
    console.error('Error fetching posts:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// 3. GET single post by ID
app.get('/api/posts/:id', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM posts WHERE id = ?', [req.params.id]);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Post not found' });
    }
    res.json({ success: true, data: formatPostResponse(rows[0], req) });
  } catch (err) {
    console.error('Error fetching post by ID:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// 4. CREATE new post (CRUD: Create)
app.post('/api/posts', upload.single('image'), async (req, res) => {
  try {
    const { title, author, imageUrl, imageUrls, videoUrl, description, category, link } = req.body;

    if (!title || title.trim() === '') {
      return res.status(400).json({ success: false, message: 'Title is required' });
    }

    let finalImageUrl = imageUrl || '';
    if (req.file) {
      finalImageUrl = `/uploads/${req.file.filename}`;
    }

    let resolvedImageUrls = [];
    if (imageUrls) {
      if (typeof imageUrls === 'string') {
        try {
          resolvedImageUrls = JSON.parse(imageUrls);
        } catch (_) {
          resolvedImageUrls = [imageUrls];
        }
      } else if (Array.isArray(imageUrls)) {
        resolvedImageUrls = imageUrls;
      }
    }
    if (resolvedImageUrls.length === 0 && finalImageUrl) {
      resolvedImageUrls = [finalImageUrl];
    }

    const newId = 'pin-' + Date.now() + '-' + crypto.randomBytes(3).toString('hex');
    const newPost = {
      id: newId,
      title: title.trim(),
      imageUrl: finalImageUrl,
      imageUrls: JSON.stringify(resolvedImageUrls),
      videoUrl: videoUrl || null,
      author: (author && author.trim()) ? author.trim() : 'Fathan',
      likes: JSON.stringify([]),
      likeCount: 0,
      description: description || null,
      category: category || 'Aesthetic',
      link: link || null,
      comments: JSON.stringify([]),
      createdAt: new Date()
    };

    await db.query(
      `INSERT INTO posts (id, title, imageUrl, imageUrls, videoUrl, author, likes, likeCount, description, category, link, comments, createdAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        newPost.id,
        newPost.title,
        newPost.imageUrl,
        newPost.imageUrls,
        newPost.videoUrl,
        newPost.author,
        newPost.likes,
        newPost.likeCount,
        newPost.description,
        newPost.category,
        newPost.link,
        newPost.comments,
        newPost.createdAt
      ]
    );

    const [createdRows] = await db.query('SELECT * FROM posts WHERE id = ?', [newId]);

    res.status(201).json({
      success: true,
      message: 'Post created successfully',
      data: formatPostResponse(createdRows[0], req)
    });
  } catch (err) {
    console.error('Error creating post:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// 5. UPDATE post (CRUD: Update/Edit)
app.put('/api/posts/:id', upload.single('image'), async (req, res) => {
  try {
    const { id } = req.params;
    const { title, imageUrl, author, description, category, link } = req.body;

    const [rows] = await db.query('SELECT * FROM posts WHERE id = ?', [id]);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Post not found' });
    }

    const existingPost = rows[0];
    let newImageUrl = existingPost.imageUrl;
    let newImageUrls = typeof existingPost.imageUrls === 'string'
      ? JSON.parse(existingPost.imageUrls || '[]')
      : (existingPost.imageUrls || []);

    if (req.file) {
      newImageUrl = `/uploads/${req.file.filename}`;
      newImageUrls = [newImageUrl];
    } else if (imageUrl && imageUrl.trim() !== '') {
      newImageUrl = imageUrl.trim();
      newImageUrls = [newImageUrl];
    }

    const updatedTitle = (title && title.trim() !== '') ? title.trim() : existingPost.title;
    const updatedAuthor = (author && author.trim()) ? author.trim() : existingPost.author;
    const updatedDescription = description !== undefined ? description : existingPost.description;
    const updatedCategory = category !== undefined ? category : existingPost.category;
    const updatedLink = link !== undefined ? link : existingPost.link;

    await db.query(
      `UPDATE posts 
       SET title = ?, imageUrl = ?, imageUrls = ?, author = ?, description = ?, category = ?, link = ?
       WHERE id = ?`,
      [
        updatedTitle,
        newImageUrl,
        JSON.stringify(newImageUrls),
        updatedAuthor,
        updatedDescription,
        updatedCategory,
        updatedLink,
        id
      ]
    );

    const [updatedRows] = await db.query('SELECT * FROM posts WHERE id = ?', [id]);

    res.json({
      success: true,
      message: 'Post updated successfully',
      data: formatPostResponse(updatedRows[0], req)
    });
  } catch (err) {
    console.error('Error updating post:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// 6. DELETE post (CRUD: Delete)
app.delete('/api/posts/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const [rows] = await db.query('SELECT * FROM posts WHERE id = ?', [id]);

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Post not found' });
    }

    const deletedPost = rows[0];

    // Clean up uploaded file if present
    if (deletedPost.imageUrl && deletedPost.imageUrl.startsWith('/uploads/')) {
      const localFile = path.join(__dirname, deletedPost.imageUrl);
      if (fs.existsSync(localFile)) {
        try {
          fs.unlinkSync(localFile);
        } catch (_) {}
      }
    }

    await db.query('DELETE FROM posts WHERE id = ?', [id]);

    res.json({
      success: true,
      message: 'Post deleted successfully',
      data: { id: deletedPost.id, title: deletedPost.title }
    });
  } catch (err) {
    console.error('Error deleting post:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// 7. LIKE / LOVE TOGGLE
app.post('/api/posts/:id/like', async (req, res) => {
  try {
    const { id } = req.params;
    const { user } = req.body;
    const username = user || 'Fathan';

    const [rows] = await db.query('SELECT * FROM posts WHERE id = ?', [id]);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Post not found' });
    }

    const post = rows[0];
    let likes = [];
    if (typeof post.likes === 'string') {
      try {
        likes = JSON.parse(post.likes);
      } catch (_) {
        likes = [];
      }
    } else if (Array.isArray(post.likes)) {
      likes = [...post.likes];
    }

    const existingIndex = likes.indexOf(username);
    let isLiked = false;

    if (existingIndex > -1) {
      likes.splice(existingIndex, 1);
      isLiked = false;
    } else {
      likes.push(username);
      isLiked = true;
    }

    const likeCount = likes.length;

    await db.query('UPDATE posts SET likes = ?, likeCount = ? WHERE id = ?', [
      JSON.stringify(likes),
      likeCount,
      id
    ]);

    res.json({
      success: true,
      message: isLiked ? 'Liked post' : 'Unliked post',
      data: {
        id: post.id,
        isLiked,
        likeCount,
        likes
      }
    });
  } catch (err) {
    console.error('Error toggling like:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// 8. ADD COMMENT
app.post('/api/posts/:id/comment', async (req, res) => {
  try {
    const { id } = req.params;
    const { user, text, avatar } = req.body;

    if (!text || text.trim() === '') {
      return res.status(400).json({ success: false, message: 'Comment text is required' });
    }

    const [rows] = await db.query('SELECT * FROM posts WHERE id = ?', [id]);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Post not found' });
    }

    const post = rows[0];
    let comments = [];
    if (typeof post.comments === 'string') {
      try {
        comments = JSON.parse(post.comments);
      } catch (_) {
        comments = [];
      }
    } else if (Array.isArray(post.comments)) {
      comments = [...post.comments];
    }

    const newComment = {
      user: user || 'Anonymous',
      avatar: avatar || (user ? user[0].toUpperCase() : 'U'),
      text: text.trim(),
      createdAt: new Date().toISOString()
    };

    comments.push(newComment);

    await db.query('UPDATE posts SET comments = ? WHERE id = ?', [
      JSON.stringify(comments),
      id
    ]);

    res.status(201).json({
      success: true,
      message: 'Comment added successfully',
      data: newComment
    });
  } catch (err) {
    console.error('Error adding comment:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({
    success: false,
    message: err.message || 'Internal server error'
  });
});

// Start listening
app.listen(PORT, '0.0.0.0', () => {
  console.log(`===============================================`);
  console.log(` Punny Express Server is running with Aiven DB!`);
  console.log(` Port: ${PORT}`);
  console.log(` Health check: http://localhost:${PORT}/api/health`);
  console.log(` Posts API:    http://localhost:${PORT}/api/posts`);
  console.log(`===============================================`);
});
