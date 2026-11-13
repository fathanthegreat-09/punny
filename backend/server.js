const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

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
  limits: { fileSize: 15 * 1024 * 1024 }, // 15MB limit
  fileFilter: (req, file, cb) => {
    const allowed = /jpeg|jpg|png|gif|webp/;
    const extName = allowed.test(path.extname(file.originalname).toLowerCase());
    const mimeType = allowed.test(file.mimetype);
    if (extName || mimeType) {
      return cb(null, true);
    }
    cb(new Error('Only image files (JPEG, PNG, GIF, WebP) are allowed!'));
  }
});

// Seed data generator
function getInitialSeedPosts() {
  return [
    {
      id: 'pin-1',
      title: 'Neon Tokyo Aesthetic',
      imageUrl: 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=800&q=80',
      author: 'Fathan',
      likes: ['user1', 'user2'],
      likeCount: 2,
      createdAt: new Date(Date.now() - 1000 * 60 * 60 * 24).toISOString()
    },
    {
      id: 'pin-2',
      title: 'Minimalist Workspace Setup',
      imageUrl: 'https://images.unsplash.com/photo-1499750310107-5fef28a66643?auto=format&fit=crop&w=800&q=80',
      author: 'Fathan',
      likes: ['user1'],
      likeCount: 1,
      createdAt: new Date(Date.now() - 1000 * 60 * 60 * 18).toISOString()
    },
    {
      id: 'pin-3',
      title: 'Mountain Sunset In Alps',
      imageUrl: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=800&q=80',
      author: 'Arona',
      likes: ['user3', 'user4', 'user5'],
      likeCount: 3,
      createdAt: new Date(Date.now() - 1000 * 60 * 60 * 12).toISOString()
    },
    {
      id: 'pin-4',
      title: 'Matcha Latte Art & Cafe Vibes',
      imageUrl: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?auto=format&fit=crop&w=800&q=80',
      author: 'Yuuka',
      likes: ['user2', 'user6'],
      likeCount: 2,
      createdAt: new Date(Date.now() - 1000 * 60 * 60 * 6).toISOString()
    },
    {
      id: 'pin-5',
      title: 'Cozy Reading Nook & Plants',
      imageUrl: 'https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=800&q=80',
      author: 'Fathan',
      likes: ['user1', 'user3', 'user4', 'user7'],
      likeCount: 4,
      createdAt: new Date(Date.now() - 1000 * 60 * 60 * 2).toISOString()
    },
    {
      id: 'pin-6',
      title: 'Cyberpunk City Street Lights',
      imageUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=800&q=80',
      author: 'Sensei',
      likes: ['user1'],
      likeCount: 1,
      createdAt: new Date(Date.now() - 1000 * 60 * 30).toISOString()
    }
  ];
}

// Read posts from JSON file helper
function readPosts() {
  try {
    if (!fs.existsSync(postsFilePath)) {
      const initial = getInitialSeedPosts();
      fs.writeFileSync(postsFilePath, JSON.stringify(initial, null, 2), 'utf-8');
      return initial;
    }
    const data = fs.readFileSync(postsFilePath, 'utf-8');
    return JSON.parse(data);
  } catch (err) {
    console.error('Error reading posts file, initializing default:', err.message);
    return getInitialSeedPosts();
  }
}

// Write posts to JSON file helper
function writePosts(posts) {
  try {
    fs.writeFileSync(postsFilePath, JSON.stringify(posts, null, 2), 'utf-8');
  } catch (err) {
    console.error('Error saving posts to file:', err.message);
  }
}

// In-memory posts initialized from file
let posts = readPosts();

// Helper to construct full URL for an image
function formatPostResponse(post, req) {
  const host = req.get('host') || `localhost:${PORT}`;
  const protocol = req.protocol || 'http';
  let formattedImageUrl = post.imageUrl;

  if (post.imagePath) {
    formattedImageUrl = `${protocol}://${host}/uploads/${path.basename(post.imagePath)}`;
  }

  return {
    ...post,
    imageUrl: formattedImageUrl,
    likeCount: Array.isArray(post.likes) ? post.likes.length : (post.likeCount || 0)
  };
}

// ======================== ROUTES ========================

// 1. Health Check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    message: 'Punny Backend is running smoothly',
    timestamp: new Date().toISOString()
  });
});

// 2. GET all posts
app.get('/api/posts', (req, res) => {
  const { author, search } = req.query;
  let filtered = [...posts];

  if (author) {
    filtered = filtered.filter(p => p.author.toLowerCase() === author.toLowerCase());
  }

  if (search) {
    const s = search.toLowerCase();
    filtered = filtered.filter(p => p.title.toLowerCase().includes(s));
  }

  // Sort newest first
  filtered.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

  const responsePosts = filtered.map(p => formatPostResponse(p, req));
  res.json({
    success: true,
    total: responsePosts.length,
    data: responsePosts
  });
});

// 3. GET single post by ID
app.get('/api/posts/:id', (req, res) => {
  const post = posts.find(p => p.id === req.params.id);
  if (!post) {
    return res.status(404).json({ success: false, message: 'Post not found' });
  }
  res.json({ success: true, data: formatPostResponse(post, req) });
});

// 4. CREATE new post (CRUD: Create)
// Supports either multipart file upload OR imageUrl field
app.post('/api/posts', upload.single('image'), (req, res) => {
  const { title, author, imageUrl } = req.body;

  if (!title || title.trim() === '') {
    return res.status(400).json({ success: false, message: 'Title is required' });
  }

  let finalImagePath = null;
  let finalImageUrl = imageUrl;

  if (req.file) {
    finalImagePath = req.file.path;
  } else if (!imageUrl || imageUrl.trim() === '') {
    return res.status(400).json({
      success: false,
      message: 'Please provide either an image file or an image URL'
    });
  }

  const newPost = {
    id: 'pin-' + Date.now() + '-' + crypto.randomBytes(3).toString('hex'),
    title: title.trim(),
    author: (author && author.trim()) ? author.trim() : 'Fathan',
    imagePath: finalImagePath,
    imageUrl: finalImageUrl || '',
    likes: [],
    likeCount: 0,
    createdAt: new Date().toISOString()
  };

  posts.unshift(newPost);
  writePosts(posts);

  res.status(201).json({
    success: true,
    message: 'Post created successfully',
    data: formatPostResponse(newPost, req)
  });
});

// 5. UPDATE post (CRUD: Update/Edit)
app.put('/api/posts/:id', upload.single('image'), (req, res) => {
  const { id } = req.params;
  const { title, imageUrl, author } = req.body;

  const postIndex = posts.findIndex(p => p.id === id);
  if (postIndex === -1) {
    return res.status(404).json({ success: false, message: 'Post not found' });
  }

  const existingPost = posts[postIndex];

  // If user provided a new file
  if (req.file) {
    // Optionally delete old uploaded file if existed
    if (existingPost.imagePath && fs.existsSync(existingPost.imagePath)) {
      try {
        fs.unlinkSync(existingPost.imagePath);
      } catch (err) {
        console.error('Failed to remove old image file:', err.message);
      }
    }
    existingPost.imagePath = req.file.path;
    existingPost.imageUrl = '';
  } else if (imageUrl && imageUrl.trim() !== '') {
    existingPost.imageUrl = imageUrl.trim();
    existingPost.imagePath = null;
  }

  if (title && title.trim() !== '') {
    existingPost.title = title.trim();
  }

  if (author && author.trim() !== '') {
    existingPost.author = author.trim();
  }

  existingPost.updatedAt = new Date().toISOString();

  posts[postIndex] = existingPost;
  writePosts(posts);

  res.json({
    success: true,
    message: 'Post updated successfully',
    data: formatPostResponse(existingPost, req)
  });
});

// 6. DELETE post (CRUD: Delete)
app.delete('/api/posts/:id', (req, res) => {
  const { id } = req.params;
  const postIndex = posts.findIndex(p => p.id === id);

  if (postIndex === -1) {
    return res.status(404).json({ success: false, message: 'Post not found' });
  }

  const [deletedPost] = posts.splice(postIndex, 1);

  // Clean up uploaded file if present
  if (deletedPost.imagePath && fs.existsSync(deletedPost.imagePath)) {
    try {
      fs.unlinkSync(deletedPost.imagePath);
    } catch (err) {
      console.error('Failed to clean up image on delete:', err.message);
    }
  }

  writePosts(posts);

  res.json({
    success: true,
    message: 'Post deleted successfully',
    data: { id: deletedPost.id, title: deletedPost.title }
  });
});

// 7. LIKE / LOVE TOGGLE
app.post('/api/posts/:id/like', (req, res) => {
  const { id } = req.params;
  const { user } = req.body;
  const username = user || 'Fathan';

  const post = posts.find(p => p.id === id);
  if (!post) {
    return res.status(404).json({ success: false, message: 'Post not found' });
  }

  if (!Array.isArray(post.likes)) {
    post.likes = [];
  }

  const existingIndex = post.likes.indexOf(username);
  let isLiked = false;

  if (existingIndex > -1) {
    // Already liked -> Unlike
    post.likes.splice(existingIndex, 1);
    isLiked = false;
  } else {
    // Not liked -> Like
    post.likes.push(username);
    isLiked = true;
  }

  post.likeCount = post.likes.length;
  writePosts(posts);

  res.json({
    success: true,
    message: isLiked ? 'Liked post' : 'Unliked post',
    data: {
      id: post.id,
      isLiked,
      likeCount: post.likeCount,
      likes: post.likes
    }
  });
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
  console.log(` Punny Express Server is running!`);
  console.log(` Port: ${PORT}`);
  console.log(` Health check: http://localhost:${PORT}/api/health`);
  console.log(` Posts API:    http://localhost:${PORT}/api/posts`);
  console.log(`===============================================`);
});
