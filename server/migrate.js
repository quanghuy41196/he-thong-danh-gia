/**
 * Database Migration Tool
 * Tự động chạy các file migration SQL theo thứ tự
 * 
 * Usage: npm run migrate
 */

import pg from 'pg';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { config } from 'dotenv';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDir = path.dirname(currentFilePath);

// Load .env từ thư mục server
config({ path: path.join(currentDir, '.env') });

const { Pool } = pg;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Database connection
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'he_thong_danh_gia',
  password: process.env.DB_PASSWORD,
  port: parseInt(process.env.DB_PORT || '5432'),
});

// Tạo bảng tracking migrations
async function createMigrationTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      id SERIAL PRIMARY KEY,
      name VARCHAR(255) UNIQUE NOT NULL,
      executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
}

// Lấy danh sách migrations đã chạy
async function getExecutedMigrations() {
  const result = await pool.query('SELECT name FROM _migrations ORDER BY id');
  return result.rows.map(row => row.name);
}

// Đánh dấu migration đã chạy
async function markMigrationExecuted(name) {
  await pool.query('INSERT INTO _migrations (name) VALUES ($1)', [name]);
}

// Chạy migration
async function runMigration(filePath, fileName) {
  console.log(`\n📄 Running: ${fileName}`);
  
  const sql = fs.readFileSync(filePath, 'utf-8');
  
  try {
    await pool.query(sql);
    await markMigrationExecuted(fileName);
    console.log(`   ✅ Success`);
    return true;
  } catch (error) {
    console.error(`   ❌ Failed: ${error.message}`);
    return false;
  }
}

// Main function
async function migrate() {
  console.log('🔄 Database Migration Tool');
  console.log('==========================');
  
  try {
    // Test connection
    await pool.query('SELECT NOW()');
    console.log('✅ Connected to PostgreSQL');
    
    // Tạo bảng tracking
    await createMigrationTable();
    
    // Lấy migrations đã chạy
    const executedMigrations = await getExecutedMigrations();
    console.log(`📋 Executed migrations: ${executedMigrations.length}`);
    
    // Tìm file migrations
    const migrationsDir = path.join(currentDir, 'migrations');
    
    if (!fs.existsSync(migrationsDir)) {
      console.log('📁 Creating migrations directory...');
      fs.mkdirSync(migrationsDir, { recursive: true });
    }
    
    const files = fs.readdirSync(migrationsDir)
      .filter(f => f.endsWith('.sql'))
      .sort();
    
    if (files.length === 0) {
      console.log('\n⚠️  No migration files found in /migrations');
      return;
    }
    
    // Chạy migrations chưa executed
    let newMigrations = 0;
    let failedMigrations = 0;
    
    for (const file of files) {
      if (!executedMigrations.includes(file)) {
        const success = await runMigration(
          path.join(migrationsDir, file),
          file
        );
        if (success) {
          newMigrations++;
        } else {
          failedMigrations++;
          break; // Dừng lại nếu có lỗi
        }
      }
    }
    
    console.log('\n==========================');
    if (newMigrations > 0) {
      console.log(`✅ Applied ${newMigrations} new migration(s)`);
    } else if (failedMigrations === 0) {
      console.log('✅ Database is up to date');
    }
    
    if (failedMigrations > 0) {
      console.log(`❌ ${failedMigrations} migration(s) failed`);
      process.exit(1);
    }
    
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Run
migrate();
