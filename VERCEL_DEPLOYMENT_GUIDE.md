# Vercel Deployment Guide for HapzText Django Backend

## Overview

This guide provides step-by-step instructions to deploy your Django REST API backend on Vercel. The project has been configured for serverless deployment with optimizations for Vercel's environment.

## Pre-Deployment Checklist

- [ ] Ensure all sensitive data is NOT in `.env` (it should only be in Vercel project settings)
- [ ] Verify database is PostgreSQL (SQLite won't work on Vercel - no persistent storage)
- [ ] Configure Redis/caching service
- [ ] Set up Cloudinary for media file storage
- [ ] Test the application locally: `python manage.py runserver`
- [ ] All changes committed and pushed to Git

## Prerequisites

1. **Vercel Account**: https://vercel.com/signup
2. **Git Repository**: Project should be hosted on GitHub, GitLab, or Bitbucket
3. **PostgreSQL Database**: Use services like:
   - Supabase
   - Railway
   - Neon
   - Cloud SQL (Google Cloud)
   - AWS RDS
4. **Redis Cache** (optional but recommended): 
   - Upstash
   - Redis Cloud
   - Railway
5. **Environment Variables** from [.env.vercel.example](.env.vercel.example)

## Step 1: Prepare Your Repository

### 1.1 Update Environment Variables

Create a `.env.vercel.example` file (already exists) and verify it contains all necessary variables:

```bash
# Copy and customize
cp .env.vercel.example .env.vercel.example
```

**Required Environment Variables:**

```env
# Django
DJANGO_SECRET_KEY=<your-secure-random-key-min-50-chars>
DJANGO_DEBUG=false
DJANGO_SETTINGS_MODULE=config.settings.production
DJANGO_ENVIRONMENT=production
DJANGO_ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com,yourproject.vercel.app

# Database (PostgreSQL - REQUIRED, SQLite won't work)
DATABASE_URL=postgresql://user:password@host:5432/dbname

# Redis (for caching)
REDIS_URL=redis://:password@host:port
REDIS_HOST=your-redis-host
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=your-password

# Cloudinary (media storage)
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret

# Email Configuration
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
EMAIL_PORT=587
EMAIL_USE_TLS=true
DEFAULT_FROM_EMAIL=noreply@yourdomain.com

# Frontend Domain
BACKEND_DOMAIN=https://yourdomain.com
CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://frontend-domain.com

# OTP
OTP_EXPIRY_MINUTES=10
```

### 1.2 Database Preparation

**Important**: SQLite (`db.sqlite3`) cannot be used on Vercel because:
- Vercel has a read-only filesystem (except `/tmp`)
- Although `/tmp` is writable, it's cleared after each function execution
- Database changes made during one request would be lost in the next

**Solution**: Use a managed PostgreSQL database:

#### Option A: Using Supabase (Recommended)
1. Go to https://supabase.com
2. Create project
3. Copy connection string: `postgresql://user:password@host/dbname`
4. In your DATABASE_URL environment variable

#### Option B: Using Railway
1. Go to https://railway.app
2. Create PostgreSQL service
3. Copy DATABASE_URL
4. Add to Vercel environment

#### Option C: Using Neon
1. Go to https://neon.tech
2. Create project
3. Copy connection string
4. Add to Vercel environment

### 1.3 Commit and Push to Git

```bash
cd /path/to/backend
git add .
git commit -m "Prepare for Vercel deployment"
git push origin main  # or your branch name
```

## Step 2: Create Vercel Project

### 2.1 Via Vercel Dashboard (Recommended)

1. Visit https://vercel.com/dashboard
2. Click "Add New" → "Project"
3. Select your Git repository
4. **Project Settings**:
   - Framework: Django
   - Root Directory: `.` (current directory)
   - Build Command: `bash build.sh`
   - Output Directory: `staticfiles`
5. Click "Deploy"

### 2.2 Via Vercel CLI

```bash
# Install Vercel CLI (if not already installed)
npm i -g vercel

# Login to Vercel
vercel

# Deploy
vercel --prod
```

## Step 3: Configure Environment Variables in Vercel

### Via Dashboard:

1. Go to project → Settings → Environment Variables
2. Add each variable from [.env.vercel.example](.env.vercel.example)
3. Set environment for: **Production**, **Preview**, **Development** (as needed)

**Critical Settings:**

- `DJANGO_SECRET_KEY`: Generate a new secure key:
  ```bash
  python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'
  ```
  
- `DJANGO_ALLOWED_HOSTS`: Your Vercel domain + custom domain
  ```
  yourdomain.com,www.yourdomain.com,your-project-name.vercel.app
  ```

- `BACKEND_DOMAIN`: Full HTTPS URL
  ```
  https://yourdomain.com
  ```

- `DATABASE_URL`: Your PostgreSQL connection string (keep secret)
  ```
  postgresql://user:password@host:5432/dbname
  ```

## Step 4: Run Database Migrations

After first deployment, connect to your application and run migrations:

### Option A: Using Vercel CLI

```bash
# SSH into the deployment
vercel ssh prod

# Inside the container
python manage.py migrate --noinput
python manage.py migrate --noinput --database=default
```

### Option B: Create a management endpoint

Create a migration endpoint (temporary):

```python
# api/v1/admin.py - REMOVE AFTER RUNNING
from django.core.management import call_command
from rest_framework.decorators import api_view
from rest_framework.response import Response

@api_view(['POST'])
def run_migrations(request):
    if request.data.get('token') != os.getenv('ADMIN_TOKEN'):
        return Response({'error': 'Unauthorized'}, status=403)
    
    try:
        call_command('migrate', '--noinput')
        return Response({'message': 'Migrations completed'})
    except Exception as e:
        return Response({'error': str(e)}, status=500)
```

## Important: Vercel Limitations & Solutions

### 1. WebSockets/Real-Time Features (CRITICAL)

**Problem**: Vercel functions have execution timeouts:
- **Standard**: 60 seconds max
- **Pro/Enterprise**: 60-900 seconds (depending on plan)

**Current Setup**: Your project uses Django Channels for WebSockets

**Solution Options**:
1. **Remove Channels** (if not critical)
   - Set `INSTALLED_APPS` to exclude `daphne` and `channels`
   - Use HTTP polling instead of WebSockets

2. **Use External WebSocket Service**:
   - Pusher (https://pusher.com) - Recommended
   - Socket.io with external server
   - Firebase Realtime
   - AWS AppSync

3. **Use Vercel Edge Middleware**:
   - Limited WebSocket support with shorter timeouts

### 2. Long-Running Background Tasks (Celery)

**Problem**: Vercel functions timeout - not suitable for Celery workers

**Solution Options**:
1. **Use External Task Queue**:
   - Celery with cloud-hosted Redis broker (Upstash)
   - But still needs separate Celery worker deployment
   
2. **Use Vercel Cron Jobs**:
   ```json
   // vercel.json - add for scheduled tasks
   {
     "crons": [{
       "path": "/api/v1/tasks/scheduled-task",
       "schedule": "0 0 * * *"  // Daily at midnight
     }]
   }
   ```

3. **Use External Service**:
   - AWS Lambda + EventBridge
   - Google Cloud Tasks
   - Railway Background Job

4. **Remove Celery**:
   - If background tasks aren't critical, disable in production:
   ```python
   # config/settings/production.py
   # Don't load Celery configuration
   ```

### 3. File Storage (IMPORTANT)

**Problem**: Vercel filesystem is mostly read-only except `/tmp`
- `/tmp` is cleared after each function execution
- Cannot persist files between requests

**Current Solution**: Using Cloudinary ✅ (Correct!)
- Verify all uploads use Cloudinary storage
- Ensure `STORAGES['default']` uses `cloudinary_storage`

**Verification**:
```python
# config/settings/base.py
STORAGES = {
    "default": {
        "BACKEND": "cloudinary_storage.storage.MediaCloudinaryStorage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}
```

### 4. Static Files

**How it works**:
1. `build.sh` runs `python manage.py collectstatic`
2. Collects all static files to `staticfiles/` directory
3. Vercel serves from `staticfiles/` with cache headers
4. WhiteNoise handles compression and caching

**Verification**:
```python
# Should see /static routes in vercel.json ✅
# Should have WhiteNoise middleware ✅
# Should use CompressedManifestStaticFilesStorage ✅
```

## Step 5: Verify Deployment

### 1. Check Build Logs
```bash
vercel logs <your-project-url>
```

### 2. Test Endpoints

```bash
# Replace with your Vercel URL
curl https://your-project.vercel.app/api/v1/
curl https://your-project.vercel.app/admin/
curl https://your-project.vercel.app/docs/swagger-ui/
```

### 3. Check Database Connection
```bash
# Via API endpoint (create temporary endpoint)
curl https://your-project.vercel.app/api/v1/health/
```

### 4. Monitor Logs
```bash
# Real-time logs
vercel logs <url> --follow

# Filter logs
vercel logs <url> --query error
```

## Step 6: Custom Domain (Optional)

1. In Vercel Dashboard → Project Settings → Domains
2. Add your custom domain
3. Update DNS records as instructed
4. Update `DJANGO_ALLOWED_HOSTS` and `BACKEND_DOMAIN`

## Troubleshooting

### "ModuleNotFoundError" during build

**Issue**: Dependencies not installing

**Solution**:
```bash
# Verify requirements files are committed
git status
# Should show no unstaged requirements.txt/requirements-prod.txt

# Rebuild
vercel --prod
```

### "404 Not Found" on all routes

**Issue**: Routing not configured correctly

**Solution**:
1. Check `vercel.json` exists and is valid
2. Verify `api/index.py` exists
3. Check build logs: `vercel logs <url>`
4. Rebuild: `vercel --prod`

### Database connection timeout

**Issue**: Can't connect to database

**Solutions**:
1. Verify `DATABASE_URL` is correct
2. Check database is accessible from Vercel IP
3. Database credentials are correct
4. Database is running and accepting connections
5. Try shorter `conn_max_age` in settings (set to 60)

### Static files returning 404

**Issue**: CSS/JS files not loading

**Solution**:
1. Verify `python manage.py collectstatic` runs in build
2. Check `STATIC_ROOT` directory exists after build
3. Verify static files are in `staticfiles/` directory
4. Clear Vercel cache: `vercel env pull` then `vercel --prod`

### "ALLOWED_HOSTS" error

**Issue**: Getting 400 Bad Request for all requests

**Solution**:
```python
# Verify in Vercel environment:
DJANGO_ALLOWED_HOSTS=yourdomain.com,yourproject.vercel.app

# Better: Make it more permissive
DJANGO_ALLOWED_HOSTS=*  # For testing only, not recommended for production
```

## Post-Deployment

### 1. Create Superuser

```bash
# Via temporary endpoint or direct management command
python manage.py createsuperuser
```

### 2. Configure CORS

Update in Vercel environment:
```
CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://frontend-app.com
```

### 3. Set Up Monitoring

Consider adding:
- Sentry (error tracking): https://sentry.io
- LogRocket (session replay): https://logrocket.com
- Vercel Analytics: Built-in

### 4. Security Checklist

- [ ] `DEBUG = False` in production
- [ ] `SECURE_SSL_REDIRECT = True`
- [ ] Strong `DJANGO_SECRET_KEY` (50+ chars)
- [ ] All secrets in Vercel env, NOT in code
- [ ] HTTPS enforced
- [ ] CORS origins restricted
- [ ] Database backups configured
- [ ] Monitor logs regularly

## Performance Optimization Tips

1. **Database Queries**:
   ```python
   # Use select_related for foreign keys
   queryset = User.objects.select_related('profile')
   ```

2. **Caching** (with Redis):
   ```python
   from django.views.decorators.cache import cache_page
   
   @cache_page(60 * 5)  # Cache for 5 minutes
   def my_view(request):
       return Response(data)
   ```

3. **Pagination**:
   ```python
   # Always paginate large querysets
   from rest_framework.pagination import LimitOffsetPagination
   ```

4. **Async Views** (Django 3.1+):
   ```python
   async def my_async_view(request):
       data = await get_async_data()
       return JsonResponse(data)
   ```

## Useful Commands

```bash
# View build logs
vercel logs <url>

# View environment variables (sensitive values hidden)
vercel env ls

# Pull environment variables
vercel env pull

# Rollback deployment
vercel rollback

# Delete deployment
vercel remove <url>

# SSH into production
vercel ssh prod

# Run command in production
vercel run "python manage.py <command>"
```

## Support & Resources

- Vercel Django Docs: https://vercel.com/docs/frameworks/django
- Django Deployment: https://docs.djangoproject.com/en/stable/howto/deployment/
- Vercel Community: https://github.com/vercel/vercel/discussions
- Django REST Framework: https://www.django-rest-framework.org/

## Rollback Instructions

If deployment fails:

```bash
# View deployments
vercel ls

# Rollback to previous version
vercel rollback
```

Or via dashboard: Project → Deployments → Select previous → Click "Promote to Production"

---

**Last Updated**: March 2026

**Next Steps**: Follow the steps above to deploy successfully! 🚀
