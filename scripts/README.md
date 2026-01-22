# Scripts Tự Động Deploy

## 📁 Danh sách Scripts

### 1. `setup-vps.sh` - Cài đặt toàn bộ hệ thống lần đầu

Script tự động cài đặt tất cả dependencies và deploy ứng dụng lên VPS Ubuntu.

**Chức năng:**
- ✅ Cài đặt Node.js, PostgreSQL, Nginx, PM2
- ✅ Tạo database và user
- ✅ Clone source code
- ✅ Build frontend
- ✅ Cấu hình PM2 cho backend
- ✅ Cấu hình Nginx
- ✅ Cài đặt SSL (nếu có domain)
- ✅ Cấu hình firewall
- ✅ Setup backup tự động

**Cách sử dụng:**

```bash
# Trên VPS Ubuntu (chạy với quyền root):
wget https://raw.githubusercontent.com/khanhvitech/he-thong-danh-gia/main/scripts/setup-vps.sh
sudo bash setup-vps.sh
```

Hoặc nếu đã clone repository:

```bash
cd /path/to/he-thong-danh-gia
sudo bash scripts/setup-vps.sh
```

Script sẽ hỏi:
- Domain (bỏ trống nếu dùng IP)
- Database password
- Có muốn cài SSL không

Sau đó tự động cài đặt tất cả!

---

### 2. `deploy.sh` - Cập nhật code khi có thay đổi

Script để cập nhật code và deploy lại sau khi đã setup xong.

**Chức năng:**
- Pull code mới từ Git
- Cài đặt dependencies mới (nếu có)
- Build lại frontend
- Restart backend

**Cách sử dụng:**

```bash
# Trên VPS (sau khi đã chạy setup-vps.sh):
cd /var/www/evaluation-system
./deploy.sh
```

---

## 🚀 Quick Start

### Lần đầu deploy lên VPS mới:

```bash
# 1. SSH vào VPS
ssh root@your-vps-ip

# 2. Download và chạy script setup
wget https://raw.githubusercontent.com/khanhvitech/he-thong-danh-gia/main/scripts/setup-vps.sh
sudo bash setup-vps.sh

# 3. Làm theo hướng dẫn trên màn hình
# Nhập domain (hoặc bỏ trống)
# Nhập database password
# Chọn có cài SSL không

# 4. Chờ 5-10 phút để script chạy xong
# 5. Truy cập URL được hiển thị ở cuối!
```

### Khi có code mới cần update:

```bash
# Trên máy local: push code
git add .
git commit -m "Update features"
git push origin main

# Trên VPS: deploy
ssh root@your-vps-ip
cd /var/www/evaluation-system
./deploy.sh
```

---

## 📋 Checklist sau khi Deploy

- [ ] Truy cập được website
- [ ] Đăng nhập thành công (Admin / ViTechGroup2025@)
- [ ] Backend API hoạt động: `curl http://localhost:5000/api/health`
- [ ] PM2 đang chạy: `pm2 status`
- [ ] Nginx đang chạy: `systemctl status nginx`
- [ ] Database kết nối OK: `psql -U evaluation_user -d evaluation_system`
- [ ] SSL hoạt động (nếu có domain): Truy cập https://

---

## 🔧 Troubleshooting

### Script báo lỗi khi chạy

```bash
# Kiểm tra quyền
sudo bash setup-vps.sh

# Xem log chi tiết
tail -f /var/log/evaluation-api-error.log
```

### Backend không chạy

```bash
pm2 logs evaluation-api
pm2 restart evaluation-api
```

### Frontend không hiển thị

```bash
# Kiểm tra Nginx
nginx -t
systemctl status nginx

# Kiểm tra file build
ls -la /var/www/evaluation-system/dist/
```

### Database lỗi

```bash
# Kiểm tra PostgreSQL
systemctl status postgresql

# Test kết nối
psql -U evaluation_user -d evaluation_system -h localhost
```

---

## 📖 Tài liệu chi tiết

Xem hướng dẫn đầy đủ tại:
- [DEPLOY.md](../DEPLOY.md) - Deploy thủ công từng bước
- [DEPLOY_SEPARATED.md](../DEPLOY_SEPARATED.md) - Deploy riêng FE/BE

---

## 💡 Tips

### Xem logs realtime

```bash
# Backend logs
pm2 logs evaluation-api --lines 100

# Nginx logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### Backup thủ công

```bash
/root/backup-db.sh
```

### Restore database

```bash
psql -U evaluation_user evaluation_system < /root/backups/db_backup_YYYYMMDD_HHMMSS.sql
```

### Monitor resources

```bash
pm2 monit
htop
df -h
```

---

## 🆘 Cần hỗ trợ?

1. Check logs: `pm2 logs` và `/var/log/nginx/error.log`
2. Check services: `systemctl status nginx postgresql`
3. Test API: `curl http://localhost:5000/api/health`
4. Mở issue trên GitHub: https://github.com/khanhvitech/he-thong-danh-gia/issues
