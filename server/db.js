import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import pg from 'pg';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load .env từ thư mục server
dotenv.config({ path: path.join(__dirname, '.env') });

const { Pool } = pg;

const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'he_thong_danh_gia',
  password: process.env.DB_PASSWORD || 'postgres',
  port: process.env.DB_PORT || 5432,
  // Prevent connection errors from crashing the app
  connectionTimeoutMillis: 5000,
});

// Test connection
pool.on('connect', () => {
  console.log('✓ Đã kết nối PostgreSQL');
});

pool.on('error', (err) => {
  console.error('❌ Lỗi PostgreSQL:', err.message);
  // Don't crash the process, let the app use JSON fallback
});

export default pool;
