# Vercel Deployment Quick Start Checklist

Complete these items in order to deploy successfully on Vercel.

## Pre-Deployment (Do Locally)

- [ ] **Environment Setup**
  - [ ] Install all project dependencies: `pip install -r requirements.txt`
  - [ ] Verify project runs locally: `python manage.py runserver`
  - [ ] Run tests: `pytest` or `python manage.py test`
  - [ ] Check for any migrations: `python manage.py makemigrations --check --dry-run`

- [ ] **Code Quality**
  - [ ] Run Django checks: `python manage.py check --deploy`
  - [ ] No import errors or missing dependencies
  - [ ] All `.env` files are in `.gitignore` (NOT committed)
  - [ ] No hardcoded secrets in code

- [ ] **Database Setup**
  - [ ] Switch from SQLite to PostgreSQL
    - [ ] Create PostgreSQL database on chosen service (Supabase, Railway, Neon, etc.)
    - [ ] Get DATABASE_URL connection string
    - [ ] Test connection locally with temporary env var
  - [ ] Run migrations locally: `python manage.py migrate`
  - [ ] Create test superuser: `python manage.py createsuperuser`

- [ ] **Media/File Storage**
  - [ ] Verify Cloudinary is configured
  - [ ] Test file upload works locally with Cloudinary
  - [ ] CLOUDINARY_* environment variables available
  - [ ] `STORAGES['default']` uses `CloudinaryStorage`

- [ ] **Static Files**
  - [ ] Run `python manage.py collectstatic --dry-run`
  - [ ] Verify staticfiles directory created successfully
  - [ ] Check WhiteNoise middleware is in MIDDLEWARE list

- [ ] **Git & Repository**
  - [ ] All changes committed: `git status` should be clean
  - [ ] Pushed to GitHub/GitLab/Bitbucket: `git push`
  - [ ] Repository is public or Vercel has access to private repo

## In Development (Vercel Dashboard)

- [ ] **Create Vercel Account**
  - [ ] Sign up at https://vercel.com
  - [ ] Authorize GitHub/GitLab/Bitbucket connection

- [ ] **Import Project**
  - [ ] Click "Add New" → "Project"
  - [ ] Select your backend repository
  - [ ] Framework preset: Django
  - [ ] Root Directory: `.` (current directory)
  - [ ] Build command: `bash build.sh`
  - [ ] Output directory: `staticfiles`
  - [ ] Skip adding environment variables for now

- [ ] **Environment Variables**
  - [ ] Generate new DJANGO_SECRET_KEY:
    ```bash
    python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'
    ```
  - [ ] Add all variables from [.env.vercel.example](.env.vercel.example):
    - [ ] `DJANGO_SECRET_KEY` (new secure key)
    - [ ] `DJANGO_DEBUG` = false
    - [ ] `DJANGO_SETTINGS_MODULE` = config.settings.production
    - [ ] `DJANGO_ALLOWED_HOSTS` = yourdomain.com,www.yourdomain.com,yourproject.vercel.app
    - [ ] `DATABASE_URL` (PostgreSQL connection string)
    - [ ] `REDIS_URL` (Redis connection string)
    - [ ] `CLOUDINARY_CLOUD_NAME`
    - [ ] `CLOUDINARY_API_KEY`
    - [ ] `CLOUDINARY_API_SECRET`
    - [ ] `EMAIL_BACKEND` (SMTP configuration)
    - [ ] `EMAIL_HOST`
    - [ ] `EMAIL_HOST_USER`
    - [ ] `EMAIL_HOST_PASSWORD`
    - [ ] `EMAIL_PORT`
    - [ ] `EMAIL_USE_TLS`
    - [ ] `DEFAULT_FROM_EMAIL`
    - [ ] `BACKEND_DOMAIN` = https://yourdomain.com
    - [ ] `CORS_ALLOWED_ORIGINS`
    - [ ] `OTP_EXPIRY_MINUTES`

- [ ] **Review Build**
  - [ ] Click "Deploy"
  - [ ] Wait for build to complete (5-10 minutes)
  - [ ] Check build logs for errors
  - [ ] All dependencies should install successfully
  - [ ] Static files should collect successfully
  - [ ] No Python errors in build output

## Post-Deployment (After Successful Build)

- [ ] **Test Basic Connectivity**
  - [ ] Visit https://yourproject.vercel.app/api/v1/
  - [ ] Should return API response (not 500 error)
  - [ ] Check admin: https://yourproject.vercel.app/admin/
  - [ ] Check Swagger docs: https://yourproject.vercel.app/docs/swagger-ui/

- [ ] **Database Operations**
  - [ ] Create superuser (choose one method):
    - Option A: Create endpoint, call it, then delete
    - Option B: SSH into Vercel: `vercel ssh prod`
    - Option C: Via Django admin panel
  - [ ] Run migrations on Vercel database (if not auto-migrated in build)
    - [ ] Ensure all migrations ran: `python manage.py showmigrations`

- [ ] **Monitor Logs**
  - [ ] Open Logs tab in Vercel dashboard
  - [ ] Monitor for errors: `vercel logs yourproject.vercel.app`
  - [ ] Check for 404s, 500s, or connection issues

- [ ] **Security Check**
  - [ ] Verify DEBUG = false
  - [ ] Check HTTPS works: `curl -I https://yourproject.vercel.app`
  - [ ] Test CORS: Send request from different origin
  - [ ] Verify no secrets in logs

- [ ] **Custom Domain (Optional)**
  - [ ] Add domain in Vercel Settings → Domains
  - [ ] Configure DNS records (instructions on Vercel)
  - [ ] Update DJANGO_ALLOWED_HOSTS with new domain
  - [ ] Update BACKEND_DOMAIN to use new domain
  - [ ] Wait for DNS propagation (up to 48 hours)
  - [ ] Test custom domain works: `curl https://yourdomain.com/api/v1/`

## Production Monitoring

- [ ] **Set Up Error Tracking**
  - [ ] (Optional) Configure Sentry for error monitoring
  - [ ] Email alerts for failures

- [ ] **Performance Monitoring**
  - [ ] Monitor function execution time
  - [ ] Check database query performance
  - [ ] Monitor cold start times

- [ ] **Logs Strategy**
  - [ ] Regularly check Vercel logs
  - [ ] Set up log aggregation if needed (LogRocket, Datadog, etc.)

- [ ] **Database Backups**
  - [ ] Enable automated backups with database provider
  - [ ] Test restore procedure

## Known Limitations & Solutions

### WebSockets/Real-Time Features
- **Problem**: Vercel functions timeout after 60-900 seconds
- **Current Setup**: Uses Django Channels
- **Status**: ⚠️ May not work reliably on Vercel
- **Solution**: 
  - [ ] Consider using Pusher, Firebase, or similar for real-time features
  - [ ] Or disable WebSocket support in production

### Background Tasks (Celery)
- **Problem**: Functions timeout, Celery can't have long-running workers
- **Current Setup**: Uses Celery for async tasks
- **Status**: ⚠️ Won't work as-is on Vercel
- **Solution**:
  - [ ] Use external Celery broker (Upstash Redis) + external worker
  - [ ] Or use Vercel Cron Jobs for scheduled tasks
  - [ ] Or remove Celery from production if not critical

### File System
- **Problem**: Vercel FS is mostly read-only, `/tmp` cleared after each request
- **Current Setup**: Uses Cloudinary
- **Status**: ✅ Properly configured

## Rollback Plan

If deployment has critical issues:

```bash
# View recent deployments
vercel ls

# Rollback to previous version
vercel rollback

# Or via Vercel Dashboard: Deployments tab → Select previous → Promote
```

## Troubleshooting Quick Links

- **Build Failing**: Check `build.sh` works locally, verify all requirements in requirements-prod.txt
- **500 Errors**: Check Vercel logs with `vercel logs yourproject.vercel.app`
- **Database Errors**: Verify DATABASE_URL is correct, test connection locally
- **Static Files 404**: Verify collectstatic completed, check whitenoise middleware
- **CORS Issues**: Check CORS_ALLOWED_ORIGINS and BACKEND_DOMAIN settings
- **Import Errors**: Verify all dependencies in requirements.txt or requirements-prod.txt

---

## After Deployment

Keep this document for reference:
- Refer to [VERCEL_DEPLOYMENT_GUIDE.md](VERCEL_DEPLOYMENT_GUIDE.md) for detailed instructions
- Check [.env.vercel.example](.env.vercel.example) for environment variable template
- Review [build.sh](build.sh) if build fails
- Check [vercel.json](vercel.json) for route/function configuration

**Status**: Ready for deployment ✅
