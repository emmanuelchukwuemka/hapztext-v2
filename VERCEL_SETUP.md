# Vercel Deployment Setup Guide

This project has been configured for deployment to Vercel. This guide explains the setup and how to use it.

## Files Added for Vercel

| File | Purpose |
|------|---------|
| `vercel.json` | Vercel configuration and routing rules |
| `api/index.py` | WSGI handler for HTTP requests |
| `api/asgi_handler.py` | Optional ASGI handler for WebSocket/Channels support |
| `build.sh` | Build script executed during Vercel build |
| `.vercelignore` | Files/folders to exclude from deployment |
| `requirements-prod.txt` | Production dependencies (gunicorn, uvicorn) |
| `.env.vercel.example` | Example environment variables for Vercel |

## Configuration Files

### vercel.json
- Routes: Handles static files and forwards HTTP requests to Django
- Build command: Runs `build.sh`
- Function timeout: 30 seconds (adjust as needed)
- Environment: Sets `DJANGO_SETTINGS_MODULE` to production

### config/settings/production.py
- Security headers enabled (HSTS, SSL redirect, secure cookies)
- Static files compression via WhiteNoise
- Optimized logging for serverless
- Production-specific Django configurations

### api/index.py
- Main WSGI entry point for Vercel functions
- Initializes Django and imports the WSGI application
- Handles all HTTP requests

## Prerequisites

Before deploying to Vercel, you need:

1. **Database**: PostgreSQL instance
   - Supabase (free tier available)
   - Railway
   - Neon
   - AWS RDS

2. **Redis**: For caching and Celery
   - Redis Cloud (free tier available)
   - Upstash
   - AWS ElastiCache

3. **File Storage**: Already configured (Cloudinary)
   - Media files stored in Cloudinary
   - Static files served via WhiteNoise

4. **Email**: SMTP service for sending emails
   - Gmail (with app-specific password)
   - SendGrid
   - Mailgun

## Quick Start

### 1. Prepare Your Repository

```bash
# Ensure git is initialized and all changes are committed
git add .
git commit -m "Add Vercel deployment configuration"
git push origin main
```

### 2. Create Vercel Account & Project

```bash
# Option A: Using Vercel CLI
npm install -g vercel
vercel login
vercel

# Option B: Using Vercel Dashboard
# Visit https://vercel.com/dashboard
```

### 3. Configure Environment Variables

Get your values ready:

| Variable | Source |
|----------|--------|
| Database | PostgreSQL connection string |
| Redis | Redis connection string |
| Secret Key | Generate: `python -c "import secrets; print(secrets.token_urlsafe(50))"` |
| Email | SMTP credentials |
| Cloudinary | Already have from config |

In Vercel Dashboard → Project Settings → Environment Variables, add all variables from `.env.vercel.example`

### 4. Deploy

```bash
# Deploy with Vercel CLI
vercel --prod

# Or use the Dashboard
# Push to Git → Vercel auto-deploys
```

### 5. Verify Deployment

```bash
# Check deployment status
vercel status

# View logs
vercel logs <your-deployment-url>

# Test the API
curl https://<your-project>.vercel.app/api/v1/health/
```

## Important Limitations

### 1. Function Timeout
- Free plan: 60 seconds
- Pro plan: 900 seconds
- WebSocket connections may timeout on free plan

### 2. No Persistent Storage
- `/logs` won't persist
- `/media` handled by Cloudinary ✅
- `/staticfiles` served via WhiteNoise ✅

### 3. Cold Starts
- First request after 15 mins of inactivity: ~2-3 seconds
- Subsequent requests: ~100-500ms

### 4. Serverless Limitations
- Cannot run long background tasks
- Celery should use external queue or scheduled tasks
- Database connections should use pooling (configured)

## Deployment Strategies

### HTTP Only (Simpler, Recommended)
- Uses `api/index.py` (WSGI)
- No WebSocket support
- Faster cold starts
- Best for REST APIs

### With WebSockets (Complex)
- Use `vercel.json` route to `api/asgi_handler.py`
- Requires uvicorn instead of gunicorn
- Function timeout limits apply
- Test thoroughly

## Database Setup Example (Supabase)

```bash
# 1. Create Supabase account and project
# 2. Go to Project Settings → Database
# 3. Copy the connection string (PostgreSQL URI)
# 4. Add to Vercel environment as DATABASE_URL
```

## Redis Setup Example (Redis Cloud)

```bash
# 1. Create Redis Cloud account
# 2. Create Flexible or Fixed subscription
# 3. Copy the connection string
# 4. Add to Vercel environment as REDIS_URL
```

## Monitoring & Debugging

### View Deployment Logs
```bash
vercel logs <your-project-url>
```

### View Real-Time Function Logs
```bash
vercel logs <your-project-url> --follow
```

### Check Django System Health
```bash
# After deployment, test:
curl https://<your-project>.vercel.app/admin/  # Should see login page
```

### Enable Debug Mode (Development Only)
```bash
# Temporarily set in Vercel:
DJANGO_DEBUG=true

# Check logs for detailed errors
vercel logs <url>
```

## Common Issues & Solutions

### Issue: "ModuleNotFoundError: No module named 'django'"
**Solution:**
- Ensure `requirements.txt` or `requirements-prod.txt` is in root
- Check build.sh is using correct pip install

### Issue: "static files not loading"
**Solution:**
```bash
# Rebuild static files:
python manage.py collectstatic --noinput
git add staticfiles/
git commit -m "Update static files"
vercel --prod
```

### Issue: "502 Bad Gateway"
**Solution:**
1. Check database connection: `vercel logs`
2. Verify DATABASE_URL is correct
3. Ensure migrations ran
4. Check ALLOWED_HOSTS includes Vercel domain

### Issue: "CSRF token missing"
**Solution:**
- Ensure CORS settings are correct
- Check CSRF_TRUSTED_ORIGINS in production.py
- Frontend must include CSRF token

### Issue: "WebSocket connection timeout"
**Solution:**
- WebSocket connections have 60-900 sec timeout
- Implement client-side reconnection logic
- Consider using polling as fallback

## Performance Optimization

### 1. Enable Caching
```python
# Static files are cached indefinitely
# Database queries cached in Redis
# Configure cache timeout as needed
```

### 2. Optimize Database Queries
```bash
# Check slow queries:
vercel logs <url> | grep "duration"
```

### 3. Monitor Cold Starts
```bash
# Track in application metrics
# Optimize imports in api/index.py
```

## Rollback Procedure

If something breaks:

```bash
# Using Vercel CLI
vercel deploy --prod  # Redeploy current code

# Or using Dashboard:
# 1. Go to Deployments
# 2. Find previous working deployment
# 3. Click → Promote to Production
```

## Security Checklist

- ✅ HTTPS enforced (automatic)
- ✅ SECRET_KEY is random and long
- ✅ DEBUG=false in production
- ✅ ALLOWED_HOSTS configured correctly
- ✅ Database credentials in environment variables
- ✅ No secrets in code or git
- ✅ CORS restricted to known origins
- ✅ HSTS enabled for 1 year

## Next Steps

1. Review `VERCEL_DEPLOYMENT.md` for detailed information
2. Use `VERCEL_CHECKLIST.md` before deployment
3. Test locally first
4. Deploy to Vercel
5. Monitor logs and errors
6. Set up error tracking (Sentry, etc.)

## Useful Resources

- [Vercel Python Documentation](https://vercel.com/docs/runtimes/python)
- [Django Deployment Checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/)
- [Channels Deployment](https://channels.readthedocs.io/en/latest/deploying.html)
- [Celery on Serverless](https://docs.celeryproject.org/en/stable/deploying.html)

## Support

- 📖 See `VERCEL_DEPLOYMENT.md` for comprehensive guide
- ✓ See `VERCEL_CHECKLIST.md` before deploying
- 💬 Check Vercel Discord: https://discord.gg/vercel
- 🐍 Django docs: https://docs.djangoproject.com/
