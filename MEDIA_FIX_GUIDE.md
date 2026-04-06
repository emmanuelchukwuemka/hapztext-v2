# Fixing Media Files 404 Error

## Problem
Flutter app is getting 404 errors when trying to load media files:
```
http://72.62.4.119:8005/media/cover_pictures/1000783003_j9FFDUS.jpg
```

## Root Cause
The `.env` file has `CLOUDINARY_CLOUD_NAME=test`, which makes Django use local file storage instead of Cloudinary. When files are uploaded, they're stored on the VPS, but may not be accessible due to:
1. File path issues
2. Django not serving media in production mode
3. Files being uploaded to Cloudinary but URLs pointing to VPS

## Solution Options

### Option 1: Use Cloudinary (RECOMMENDED) ⭐

**Benefits:**
- Cloud storage (files persist even if VPS is reset)
- Better performance with CDN
- Scalable
- No server storage management needed

**Steps:**

1. **Get Cloudinary Credentials:**
   - Go to https://cloudinary.com
   - Sign up for a free account
   - Get your credentials from Dashboard:
     - Cloud Name
     - API Key
     - API Secret

2. **Update Local .env:**
   ```bash
   # Replace 'test' values with your actual credentials
   CLOUDINARY_CLOUD_NAME=your-cloud-name
   CLOUDINARY_API_KEY=your-api-key
   CLOUDINARY_API_SECRET=your-api-secret
   ```

3. **Update Deploy Script:**
   Edit `deploy_vps.py` lines 134-136 to use real credentials or prompt for them:
   ```python
   # Instead of 'test', use actual values
   f"grep -q 'CLOUDINARY_CLOUD_NAME' {REMOTE_PATH}/.env || echo 'CLOUDINARY_CLOUD_NAME={YOUR_CLOUD_NAME}' >> {REMOTE_PATH}/.env",
   f"grep -q 'CLOUDINARY_API_KEY' {REMOTE_PATH}/.env || echo 'CLOUDINARY_API_KEY={YOUR_API_KEY}' >> {REMOTE_PATH}/.env",
   f"grep -q 'CLOUDINARY_API_SECRET' {REMOTE_PATH}/.env || echo 'CLOUDINARY_API_SECRET={YOUR_API_SECRET}' >> {REMOTE_PATH}/.env",
   ```

4. **Redeploy to VPS:**
   ```bash
   python deploy_vps.py
   ```

5. **Verify:**
   - Upload a new profile/cover picture
   - Check that the URL returned uses Cloudinary (e.g., `https://res.cloudinary.com/...`)
   - The Flutter app should load images without 404 errors

---

### Option 2: Use Local File Storage on VPS

**When to use:** Testing, development, or if you don't want to use Cloudinary

**Steps:**

1. **Keep test credentials in .env:**
   ```bash
   CLOUDINARY_CLOUD_NAME=test
   CLOUDINARY_API_KEY=test
   CLOUDINARY_API_SECRET=test
   ```

2. **Ensure Django serves media in production:**
   ✅ Already configured in `config/settings/production.py`:
   ```python
   SERVE_MEDIA_IN_PRODUCTION = True
   ```

3. **Verify media directory exists on VPS:**
   ```bash
   ssh root@72.62.4.119
   ls -la /root/hapz_backend/media/
   chmod -R 755 /root/hapz_backend/media/
   ```

4. **Check file actually exists:**
   ```bash
   ls -la /root/hapz_backend/media/cover_pictures/
   ```

5. **Restart Daphne:**
   ```bash
   cd /root/hapz_backend
   source .venv/bin/activate
   pkill -f daphne
   python manage.py runserver 0.0.0.0:8005
   ```

6. **Test access:**
   ```bash
   curl http://72.62.4.119:8005/media/cover_pictures/1000783003_j9FFDUS.jpg
   ```

---

## Quick Fix (Right Now)

If you need an immediate fix and already have files on the VPS:

1. **SSH into VPS:**
   ```bash
   ssh root@72.62.4.119
   ```

2. **Check if file exists:**
   ```bash
   ls -la /root/hapz_backend/media/cover_pictures/1000783003_j9FFDUS.jpg
   ```

3. **If file doesn't exist, check where uploads are going:**
   ```bash
   find /root/hapz_backend -name "*.jpg" -type f | head -20
   ```

4. **Check Django settings:**
   ```bash
   cd /root/hapz_backend
   source .venv/bin/activate
   python -c "from django.conf import settings; print('MEDIA_ROOT:', settings.MEDIA_ROOT); print('USE_CLOUDINARY:', getattr(settings, 'USE_CLOUDINARY', False))"
   ```

5. **Restart Daphne to apply new settings:**
   ```bash
   pkill -f daphne
   cd /root/hapz_backend
   source .venv/bin/activate
   nohup daphne -b 0.0.0.0 -p 8005 config.asgi:application > logs/daphne.log 2>&1 &
   ```

---

## Verification Checklist

After applying either solution:

- [ ] Django backend is running
- [ ] Media endpoint responds: `http://72.62.4.119:8005/media/`
- [ ] Can access specific file: `http://72.62.4.119:8005/media/cover_pictures/test.jpg`
- [ ] Flutter app can load images without 404
- [ ] New uploads work correctly

---

## Recommended Next Steps

1. **Use Cloudinary** - It's the proper solution for production
2. **Update deploy script** to accept Cloudinary credentials as parameters
3. **Add health check** for media endpoint in your deployment script
4. **Consider using Nginx** to serve media files directly instead of through Django
