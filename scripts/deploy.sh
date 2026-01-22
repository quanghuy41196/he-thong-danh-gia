#!/bin/bash

# Script cập nhật code (chạy trên VPS sau khi đã setup xong)
# Chạy: ./deploy.sh

set -e

echo "🚀 Starting deployment..."

APP_DIR="/var/www/evaluation-system"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Check if directory exists
if [ ! -d "$APP_DIR" ]; then
    echo "❌ Directory $APP_DIR does not exist. Please run setup-vps.sh first!"
    exit 1
fi

cd "$APP_DIR"

# Pull latest code
print_info "Pulling latest code from Git..."
git pull origin main
print_success "Code updated"

# Install dependencies
print_info "Installing dependencies..."
npm install
print_success "Dependencies installed"

# Build frontend
print_info "Building frontend..."
npm run build
print_success "Frontend built"

# Restart backend
print_info "Restarting backend..."
pm2 restart evaluation-api
print_success "Backend restarted"

# Show status
echo ""
pm2 status
echo ""
print_success "Deployment completed successfully!"
echo ""
echo "Check logs: pm2 logs evaluation-api"
