const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: {
    rejectUnauthorized: false // Mengizinkan SSL connection ke Aiven
  },
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Otomatis buat tabel posts jika belum ada
async function initDb() {
  const createTableQuery = `
    CREATE TABLE IF NOT EXISTS posts (
      id VARCHAR(100) PRIMARY KEY,
      title VARCHAR(255) NOT NULL,
      imageUrl TEXT,
      imageUrls JSON,
      videoUrl TEXT,
      videoUrls JSON,
      author VARCHAR(100) NOT NULL,
      likes JSON,
      likeCount INT DEFAULT 0,
      description TEXT,
      category VARCHAR(100),
      link TEXT,
      comments JSON,
      createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `;
  await pool.query(createTableQuery);

  // Ensure videoUrls column exists for backward compatibility
  try {
    const [cols] = await pool.query(
      "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'posts' AND COLUMN_NAME = 'videoUrls'"
    );
    if (cols.length === 0) {
      await pool.query('ALTER TABLE posts ADD COLUMN videoUrls JSON');
    }
  } catch (colErr) {
    console.error('Error verifying videoUrls column:', colErr.message);
  }

  console.log('Connected to Aiven Database and table ready!');
}

initDb().catch(err => console.error('Database connection error:', err));

module.exports = pool;