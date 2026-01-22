#!/bin/bash

# Script tự động cài đặt và deploy hệ thống đánh giá lên VPS
# Chạy với quyền root: sudo bash setup-vps.sh

set -e  # Exit on error

echo "🚀 Bắt đầu cài đặt hệ thống đánh giá..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Vui lòng chạy script với quyền root: sudo bash setup-vps.sh"
    exit 1
fi

# Get user input
print_info "Nhập thông tin cấu hình..."
read -p "Domain của bạn (để trống nếu dùng IP): " DOMAIN
read -p "Database password (mặc định: ViTech@2026): " DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-ViTech@2026}

print_info "Bạn có muốn cài đặt SSL certificate? (y/n) [y]: " SSL_INSTALL
SSL_INSTALL=${SSL_INSTALL:-y}

echo ""
print_info "=== Thông tin cấu hình ==="
echo "Domain: ${DOMAIN:-Dùng IP}"
echo "Database Password: $DB_PASSWORD"
echo "SSL: ${SSL_INSTALL}"
echo ""
read -p "Xác nhận cấu hình? (y/n) [y]: " CONFIRM
CONFIRM=${CONFIRM:-y}

if [ "$CONFIRM" != "y" ]; then
    print_error "Hủy cài đặt"
    exit 1
fi

# ============================================
# STEP 1: Update system
# ============================================
print_info "Bước 1: Cập nhật hệ thống..."
apt update && apt upgrade -y
print_success "Cập nhật hệ thống thành công"

# ============================================
# STEP 2: Install Node.js
# ============================================
print_info "Bước 2: Cài đặt Node.js 18.x..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
    print_success "Node.js $(node -v) đã được cài đặt"
else
    print_success "Node.js $(node -v) đã có sẵn"
fi

# ============================================
# STEP 3: Install PostgreSQL
# ============================================
print_info "Bước 3: Cài đặt PostgreSQL..."
if ! command -v psql &> /dev/null; then
    apt install -y postgresql postgresql-contrib
    systemctl start postgresql
    systemctl enable postgresql
    print_success "PostgreSQL đã được cài đặt"
else
    print_success "PostgreSQL đã có sẵn"
fi

# ============================================
# STEP 4: Setup Database
# ============================================
print_info "Bước 4: Cấu hình database..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS evaluation_system;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS evaluation_user;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE evaluation_system;"
sudo -u postgres psql -c "CREATE USER evaluation_user WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE evaluation_system TO evaluation_user;"
print_success "Database đã được tạo"

# ============================================
# STEP 5: Install Nginx
# ============================================
print_info "Bước 5: Cài đặt Nginx..."
if ! command -v nginx &> /dev/null; then
    apt install -y nginx
    systemctl start nginx
    systemctl enable nginx
    print_success "Nginx đã được cài đặt"
else
    print_success "Nginx đã có sẵn"
fi

# ============================================
# STEP 6: Install PM2
# ============================================
print_info "Bước 6: Cài đặt PM2..."
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
    print_success "PM2 đã được cài đặt"
else
    print_success "PM2 đã có sẵn"
fi

# ============================================
# STEP 7: Clone source code
# ============================================
print_info "Bước 7: Clone source code..."
APP_DIR="/var/www/evaluation-system"
if [ -d "$APP_DIR" ]; then
    print_info "Thư mục đã tồn tại, đang backup..."
    mv "$APP_DIR" "${APP_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
fi

mkdir -p "$APP_DIR"
cd "$APP_DIR"
git clone https://github.com/khanhvitech/he-thong-danh-gia.git .
print_success "Source code đã được clone"

# ============================================
# STEP 8: Configure Backend
# ============================================
print_info "Bước 8: Cấu hình Backend..."
cat > "$APP_DIR/server/.env" <<EOF
PORT=5000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=evaluation_system
DB_USER=evaluation_user
DB_PASSWORD=$DB_PASSWORD
NODE_ENV=production
EOF
print_success "Backend đã được cấu hình"

# ============================================
# STEP 9: Install dependencies & Init DB
# ============================================
print_info "Bước 9: Cài đặt dependencies..."
npm install
print_success "Dependencies đã được cài đặt"

print_info "Khởi tạo database..."
npm run init-db
print_success "Database đã được khởi tạo"

# ============================================
# STEP 10: Update API URL & Build Frontend
# ============================================
print_info "Bước 10: Build Frontend..."
if [ -n "$DOMAIN" ]; then
    # Update API URL in source
    sed -i "s|http://localhost:5000/api|/api|g" "$APP_DIR/src/services/api.ts"
fi
npm run build
print_success "Frontend đã được build"

# ============================================
# STEP 11: Setup PM2
# ============================================
print_info "Bước 11: Cấu hình PM2..."
cat > "$APP_DIR/ecosystem.config.js" <<EOF
module.exports = {
  apps: [{
    name: 'evaluation-api',
    script: './server/index.js',
    cwd: '$APP_DIR',
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
EOF

pm2 delete evaluation-api 2>/dev/null || true
pm2 start ecosystem.config.js
pm2 save
pm2 startup | tail -n 1 | bash
print_success "PM2 đã được cấu hình"

# ============================================
# STEP 12: Configure Nginx
# ============================================
print_info "Bước 12: Cấu hình Nginx..."

if [ -n "$DOMAIN" ]; then
    SERVER_NAME="$DOMAIN www.$DOMAIN"
else
    SERVER_NAME="$(hostname -I | awk '{print $1}')"
fi

cat > /etc/nginx/sites-available/evaluation-system <<EOF
server {
    listen 80;
    server_name $SERVER_NAME;

    root $APP_DIR/dist;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Frontend routing
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

ln -sf /etc/nginx/sites-available/evaluation-system /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
print_success "Nginx đã được cấu hình"

# ============================================
# STEP 13: Configure Firewall
# ============================================
print_info "Bước 13: Cấu hình Firewall..."
if command -v ufw &> /dev/null; then
    ufw --force enable
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    print_success "Firewall đã được cấu hình"
else
    print_info "UFW chưa được cài đặt, bỏ qua cấu hình firewall"
fi

# ============================================
# STEP 14: Install SSL (if domain provided)
# ============================================
if [ -n "$DOMAIN" ] && [ "$SSL_INSTALL" = "y" ]; then
    print_info "Bước 14: Cài đặt SSL Certificate..."
    apt install -y certbot python3-certbot-nginx
    certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email
    print_success "SSL Certificate đã được cài đặt"
else
    print_info "Bỏ qua cài đặt SSL"
fi

# ============================================
# STEP 15: Create deploy script
# ============================================
print_info "Bước 15: Tạo script deploy..."
cat > "$APP_DIR/deploy.sh" <<'EOF'
#!/bin/bash
echo "🚀 Starting deployment..."
cd /var/www/evaluation-system
git pull origin main
npm install
npm run build
pm2 restart evaluation-api
echo "✅ Deployment completed!"
EOF
chmod +x "$APP_DIR/deploy.sh"
print_success "Script deploy đã được tạo"

# ============================================
# STEP 16: Setup backup
# ============================================
print_info "Bước 16: Cấu hình backup tự động..."
cat > /root/backup-db.sh <<EOF
#!/bin/bash
BACKUP_DIR="/root/backups"
DATE=\$(date +%Y%m%d_%H%M%S)
mkdir -p \$BACKUP_DIR
PGPASSWORD='$DB_PASSWORD' pg_dump -U evaluation_user -h localhost evaluation_system > \$BACKUP_DIR/db_backup_\$DATE.sql
find \$BACKUP_DIR -name "db_backup_*.sql" -mtime +7 -delete
echo "Backup completed: db_backup_\$DATE.sql"
EOF
chmod +x /root/backup-db.sh

# Add to crontab if not exists
(crontab -l 2>/dev/null | grep -q '/root/backup-db.sh') || \
    (crontab -l 2>/dev/null; echo "0 2 * * * /root/backup-db.sh") | crontab -
print_success "Backup tự động đã được cấu hình (chạy hàng ngày lúc 2h sáng)"

# ============================================
# COMPLETION
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║          🎉 CÀI ĐẶT HOÀN TẤT THÀNH CÔNG! 🎉              ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
print_success "Backend đang chạy trên PM2"
print_success "Frontend đã được build và serve bởi Nginx"
print_success "Database PostgreSQL đã sẵn sàng"
[ -n "$DOMAIN" ] && [ "$SSL_INSTALL" = "y" ] && print_success "SSL Certificate đã được cài đặt"
echo ""
echo "📝 THÔNG TIN TRUY CẬP:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -n "$DOMAIN" ]; then
    if [ "$SSL_INSTALL" = "y" ]; then
        echo "🌐 URL: https://$DOMAIN"
    else
        echo "🌐 URL: http://$DOMAIN"
    fi
else
    echo "🌐 URL: http://$(hostname -I | awk '{print $1}')"
fi
echo "👤 Username: Admin"
echo "🔑 Password: ViTechGroup2025@"
echo ""
echo "📊 KIỂM TRA HỆ THỐNG:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Backend: pm2 status"
echo "Logs: pm2 logs evaluation-api"
echo "Nginx: systemctl status nginx"
echo "Database: psql -U evaluation_user -d evaluation_system"
echo ""
echo "🔄 CẬP NHẬT CODE SAU NÀY:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "cd /var/www/evaluation-system"
echo "./deploy.sh"
echo ""
echo "💾 BACKUP DATABASE:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tự động: Hàng ngày lúc 2h sáng"
echo "Thủ công: /root/backup-db.sh"
echo "Restore: psql -U evaluation_user evaluation_system < /root/backups/db_backup_*.sql"
echo ""
print_info "Xem hướng dẫn chi tiết tại: DEPLOY.md"
echo ""
