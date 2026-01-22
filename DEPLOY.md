# Hướng dẫn Deploy lên VPS

## Yêu cầu VPS

- **OS**: Ubuntu 20.04 LTS trở lên
- **RAM**: Tối thiểu 2GB
- **CPU**: 1 core
- **Disk**: 20GB SSD
- **Domain**: Có domain trỏ về VPS (optional nhưng khuyến khích)

---

## Bước 1: Chuẩn bị VPS

### 1.1. Kết nối SSH vào VPS

```bash
ssh root@your-vps-ip
```

### 1.2. Cập nhật hệ thống

```bash
apt update && apt upgrade -y
```

### 1.3. Cài đặt các dependencies cần thiết

```bash
# Cài đặt Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Cài đặt PostgreSQL
apt install -y postgresql postgresql-contrib

# Cài đặt Nginx
apt install -y nginx

# Cài đặt PM2 (Process Manager)
npm install -g pm2

# Cài đặt Git
apt install -y git
```

---

## Bước 2: Cấu hình PostgreSQL

### 2.1. Tạo database và user

```bash
# Chuyển sang user postgres
sudo -u postgres psql

# Trong PostgreSQL shell:
CREATE DATABASE evaluation_system;
CREATE USER evaluation_user WITH PASSWORD 'your_strong_password';
GRANT ALL PRIVILEGES ON DATABASE evaluation_system TO evaluation_user;
\q
```

### 2.2. Cho phép kết nối từ localhost

```bash
# Edit pg_hba.conf
nano /etc/postgresql/*/main/pg_hba.conf

# Thêm dòng này:
# local   all             evaluation_user                                 md5

# Restart PostgreSQL
systemctl restart postgresql
```

---

## Bước 3: Clone và cấu hình source code

### 3.1. Tạo thư mục cho ứng dụng

```bash
mkdir -p /var/www/evaluation-system
cd /var/www/evaluation-system
```

### 3.2. Clone repository

```bash
git clone https://github.com/khanhvitech/he-thong-danh-gia.git .
```

### 3.3. Cấu hình Backend

```bash
# Tạo file .env cho server
cd /var/www/evaluation-system/server
nano .env
```

Thêm nội dung:

```env
PORT=5000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=evaluation_system
DB_USER=evaluation_user
DB_PASSWORD=your_strong_password
NODE_ENV=production
```

### 3.4. Cài đặt dependencies

```bash
# Backend dependencies
cd /var/www/evaluation-system
npm install

# Khởi tạo database
npm run init-db
```

---

## Bước 4: Build Frontend

### 4.1. Update API URL

```bash
nano src/services/api.ts
```

Thay đổi:

```typescript
// Từ:
const API_BASE_URL = 'http://localhost:5000/api';

// Thành (nếu có domain):
const API_BASE_URL = 'https://yourdomain.com/api';

// Hoặc (nếu dùng IP):
const API_BASE_URL = 'http://your-vps-ip:5000/api';
```

### 4.2. Build frontend

```bash
npm run build
```

Frontend sẽ được build vào thư mục `dist/`

---

## Bước 5: Cấu hình PM2 cho Backend

### 5.1. Tạo file ecosystem

```bash
cd /var/www/evaluation-system
nano ecosystem.config.js
```

Thêm nội dung:

```javascript
module.exports = {
  apps: [{
    name: 'evaluation-api',
    script: './server/index.js',
    cwd: '/var/www/evaluation-system',
    instances: 2,
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: '/var/log/evaluation-api-error.log',
    out_file: '/var/log/evaluation-api-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
```

### 5.2. Khởi động backend với PM2

```bash
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

---

## Bước 6: Cấu hình Nginx

### 6.1. Tạo file cấu hình Nginx

```bash
nano /etc/nginx/sites-available/evaluation-system
```

**Option 1: Nếu có domain**

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    # Frontend
    root /var/www/evaluation-system/dist;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Frontend routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

**Option 2: Nếu chỉ dùng IP**

```nginx
server {
    listen 80;
    server_name your-vps-ip;

    root /var/www/evaluation-system/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### 6.2. Enable site và restart Nginx

```bash
# Tạo symbolic link
ln -s /etc/nginx/sites-available/evaluation-system /etc/nginx/sites-enabled/

# Test cấu hình
nginx -t

# Restart Nginx
systemctl restart nginx
```

---

## Bước 7: Cài đặt SSL (Nếu có domain)

### 7.1. Cài đặt Certbot

```bash
apt install -y certbot python3-certbot-nginx
```

### 7.2. Lấy SSL certificate

```bash
certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

### 7.3. Tự động gia hạn SSL

```bash
# Test renewal
certbot renew --dry-run

# Crontab sẽ tự động được tạo
```

---

## Bước 8: Cấu hình Firewall

```bash
# Cho phép SSH
ufw allow 22/tcp

# Cho phép HTTP và HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall
ufw enable
```

---

## Bước 9: Kiểm tra và Monitoring

### 9.1. Kiểm tra backend

```bash
pm2 status
pm2 logs evaluation-api
```

### 9.2. Kiểm tra Nginx

```bash
systemctl status nginx
tail -f /var/log/nginx/access.log
```

### 9.3. Test API

```bash
curl http://localhost:5000/api/health
```

### 9.4. Truy cập ứng dụng

- Mở trình duyệt: `http://yourdomain.com` hoặc `http://your-vps-ip`
- Đăng nhập: 
  - Username: `Admin`
  - Password: `ViTechGroup2025@`

---

## Bước 10: Cập nhật code (Deploy lần sau)

### 10.1. Script tự động deploy

Tạo file `deploy.sh`:

```bash
nano /var/www/evaluation-system/deploy.sh
```

```bash
#!/bin/bash

echo "🚀 Starting deployment..."

# Pull latest code
cd /var/www/evaluation-system
git pull origin main

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Build frontend
echo "🏗️  Building frontend..."
npm run build

# Restart backend
echo "🔄 Restarting backend..."
pm2 restart evaluation-api

echo "✅ Deployment completed!"
```

Cấp quyền thực thi:

```bash
chmod +x /var/www/evaluation-system/deploy.sh
```

### 10.2. Deploy khi có thay đổi

```bash
cd /var/www/evaluation-system
./deploy.sh
```

---

## Troubleshooting

### Lỗi kết nối database

```bash
# Kiểm tra PostgreSQL
systemctl status postgresql

# Kiểm tra log
tail -f /var/log/postgresql/postgresql-*-main.log

# Test kết nối
psql -U evaluation_user -d evaluation_system -h localhost
```

### Backend không chạy

```bash
# Xem log PM2
pm2 logs evaluation-api --lines 100

# Restart
pm2 restart evaluation-api

# Xem chi tiết
pm2 describe evaluation-api
```

### Frontend không load

```bash
# Kiểm tra Nginx
nginx -t
systemctl status nginx

# Xem log
tail -f /var/log/nginx/error.log

# Kiểm tra quyền file
ls -la /var/www/evaluation-system/dist/
```

### Port 5000 bị chiếm

```bash
# Tìm process đang dùng port
lsof -i :5000

# Kill process
kill -9 <PID>
```

---

## Backup và Restore

### Backup Database

```bash
# Tạo script backup
nano /root/backup-db.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/root/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

pg_dump -U evaluation_user evaluation_system > $BACKUP_DIR/db_backup_$DATE.sql

# Giữ lại 7 backup gần nhất
find $BACKUP_DIR -name "db_backup_*.sql" -mtime +7 -delete

echo "Backup completed: db_backup_$DATE.sql"
```

```bash
chmod +x /root/backup-db.sh

# Thêm vào crontab (chạy hàng ngày lúc 2h sáng)
crontab -e
# Thêm dòng:
0 2 * * * /root/backup-db.sh
```

### Restore Database

```bash
psql -U evaluation_user evaluation_system < /root/backups/db_backup_YYYYMMDD_HHMMSS.sql
```

---

## Monitoring và Performance

### Setup monitoring với PM2

```bash
# Install PM2 monitoring (optional)
pm2 install pm2-logrotate

# Set log rotation
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7
```

### Check resource usage

```bash
# CPU và RAM
htop

# Disk usage
df -h

# PM2 monitoring
pm2 monit
```

---

## Bảo mật nâng cao

### 1. Đổi SSH port

```bash
nano /etc/ssh/sshd_config
# Đổi Port 22 thành Port 2222
systemctl restart sshd
```

### 2. Disable root login

```bash
nano /etc/ssh/sshd_config
# PermitRootLogin no
```

### 3. Setup fail2ban

```bash
apt install fail2ban
systemctl enable fail2ban
systemctl start fail2ban
```

---

## Tổng kết

Sau khi hoàn thành tất cả các bước:

✅ Backend chạy trên PM2 tại port 5000  
✅ Frontend được serve bởi Nginx  
✅ PostgreSQL database  
✅ SSL certificate (nếu có domain)  
✅ Firewall được cấu hình  
✅ Auto backup database  
✅ Script deploy tự động  

**URL truy cập:**
- Production: `https://yourdomain.com` hoặc `http://your-vps-ip`
- API: `https://yourdomain.com/api/health`

**Credentials mặc định:**
- Username: `Admin`
- Password: `ViTechGroup2025@`

---

## Liên hệ hỗ trợ

Nếu gặp vấn đề trong quá trình deploy, vui lòng:
1. Kiểm tra logs: `pm2 logs` và `/var/log/nginx/error.log`
2. Kiểm tra services: `systemctl status nginx postgresql`
3. Test API: `curl http://localhost:5000/api/health`
