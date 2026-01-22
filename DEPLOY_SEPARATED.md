# Deploy Frontend và Backend riêng biệt

## Khi nào nên tách riêng?

✅ Traffic lớn, cần scale riêng FE và BE  
✅ Frontend deploy lên CDN (Vercel, Netlify, Cloudflare Pages)  
✅ Backend cần nhiều resources hơn  
✅ Muốn CI/CD riêng cho từng phần  

---

## Option 1: Backend riêng + Frontend trên Vercel/Netlify

### Backend (VPS)

**1. Deploy backend lên VPS**

```bash
# Clone và setup như bình thường
cd /var/www/evaluation-api
git clone https://github.com/khanhvitech/he-thong-danh-gia.git .

# Chỉ cần backend
cd server
npm install

# Cấu hình .env
nano .env
```

```env
PORT=5000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=evaluation_system
DB_USER=evaluation_user
DB_PASSWORD=your_password
NODE_ENV=production
CORS_ORIGIN=https://your-frontend-domain.vercel.app
```

**2. Cập nhật CORS trong server/index.js**

```javascript
import cors from 'cors';

const allowedOrigins = [
  'https://your-frontend-domain.vercel.app',
  'https://your-custom-domain.com',
];

app.use(cors({
  origin: function(origin, callback) {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true
}));
```

**3. PM2 chạy backend**

```bash
pm2 start server/index.js --name evaluation-api
pm2 save
```

**4. Nginx cho backend (API only)**

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;  # Subdomain cho API

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # CORS headers (nếu cần)
        add_header 'Access-Control-Allow-Origin' 'https://your-frontend-domain.vercel.app' always;
        add_header 'Access-Control-Allow-Credentials' 'true' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type' always;
    }
}
```

**5. SSL cho API**

```bash
certbot --nginx -d api.yourdomain.com
```

### Frontend (Vercel)

**1. Update API URL**

Sửa `src/services/api.ts`:

```typescript
const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://api.yourdomain.com';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // Nếu cần cookies
});
```

**2. Tạo file `.env.production`**

```env
VITE_API_URL=https://api.yourdomain.com
```

**3. Deploy lên Vercel**

```bash
# Cài Vercel CLI
npm install -g vercel

# Login
vercel login

# Deploy
vercel --prod
```

Hoặc kết nối GitHub với Vercel (auto deploy):
1. Vào https://vercel.com
2. Import repository
3. Set environment variable: `VITE_API_URL=https://api.yourdomain.com`
4. Deploy

---

## Option 2: Cả 2 trên VPS riêng

### Server 1: Backend

```bash
# VPS 1 (Backend) - 103.15.50.10
cd /var/www/evaluation-api
# Setup như bên trên
```

### Server 2: Frontend

```bash
# VPS 2 (Frontend) - 103.15.50.20

# Build frontend
cd /var/www/evaluation-frontend
git clone https://github.com/khanhvitech/he-thong-danh-gia.git .

# Update API URL
nano src/services/api.ts
# const API_BASE_URL = 'https://api.yourdomain.com';

npm install
npm run build

# Nginx serve static files
```

**Nginx config (Frontend server)**

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    root /var/www/evaluation-frontend/dist;
    index index.html;

    # Frontend routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

---

## Option 3: Backend VPS + Frontend Netlify

### Backend (VPS)
Giống Option 1

### Frontend (Netlify)

**1. Update API URL**

Tạo `.env.production`:

```env
VITE_API_URL=https://api.yourdomain.com
```

**2. Tạo `netlify.toml`**

```toml
[build]
  command = "npm run build"
  publish = "dist"

[build.environment]
  NODE_VERSION = "18"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

**3. Deploy**

```bash
# Cài Netlify CLI
npm install -g netlify-cli

# Login
netlify login

# Deploy
netlify deploy --prod
```

Hoặc kết nối GitHub với Netlify.

---

## So sánh các phương án

| Phương án | Chi phí | Độ phức tạp | Performance | Scale |
|-----------|---------|-------------|-------------|-------|
| **Cùng 1 VPS** | $ | ⭐ | ⭐⭐ | ⭐ |
| **BE VPS + FE Vercel** | $$ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **2 VPS riêng** | $$$ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **BE VPS + FE Netlify** | $$ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## Khuyến nghị

### Cho dự án nhỏ - vừa (< 1000 users/ngày):
👉 **Dùng 1 VPS** (theo DEPLOY.md chính)
- Chi phí thấp: $5-10/tháng
- Dễ quản lý
- Đủ cho hầu hết use case

### Cho dự án lớn hơn:
👉 **Backend VPS + Frontend Vercel/Netlify**
- FE được cache CDN global → Nhanh hơn
- BE scale riêng khi cần
- Chi phí: Backend VPS $10 + Vercel/Netlify free tier

### Cho enterprise:
👉 **Kubernetes hoặc Cloud Services**
- AWS/Azure/GCP
- Auto scaling
- High availability

---

## Lưu ý khi tách riêng

### 1. CORS
Backend phải cho phép frontend domain:

```javascript
app.use(cors({
  origin: 'https://your-frontend-domain.com',
  credentials: true
}));
```

### 2. Environment Variables
Frontend cần biết API URL:

```typescript
const API_BASE_URL = import.meta.env.VITE_API_URL;
```

### 3. SSL/HTTPS
- Backend: `https://api.yourdomain.com`
- Frontend: `https://yourdomain.com`
- Mixed content (http + https) sẽ bị block

### 4. Cookies/Session
Nếu dùng cookies, cần:

```javascript
// Backend
app.use(cors({
  origin: 'https://frontend.com',
  credentials: true
}));

// Frontend
axios.create({
  withCredentials: true
});
```

---

## Kết luận

**Với dự án này:**
- Bắt đầu với **1 VPS** (DEPLOY.md)
- Khi traffic tăng → chuyển sang **Backend VPS + Frontend CDN**
- Không cần tách riêng ngay từ đầu trừ khi có lý do cụ thể

Cùng 1 dự án vẫn chạy được hoàn toàn bình thường! 🚀
