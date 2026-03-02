# Vercel Deployment Checklist

Use this checklist before deploying to Vercel.

## Pre-Deployment

- [ ] All code committed and pushed to repository
- [ ] `.env` file NOT in git (check .gitignore)
- [ ] Database migrated locally
- [ ] Static files collected locally (`python manage.py collectstatic`)
- [ ] All tests passing (`pytest` or `python manage.py test`)
- [ ] No console errors in development

## Environment Setup

- [ ] PostgreSQL database created (use Supabase, Railway, or similar)
- [ ] Redis instance created (use Redis Cloud or similar)
- [ ] Cloudinary account configured
- [ ] All environment variables ready

## Vercel Configuration

- [ ] Vercel account created (vercel.com)
- [ ] Repository connected to Vercel
- [ ] `vercel.json` exists in root
- [ ] `build.sh` exists and is executable
- [ ] `api/index.py` exists with WSGI handler
- [ ] `requirements-prod.txt` or `requirements.txt` exists

## Environment Variables in Vercel

Set these in Vercel Dashboard → Settings → Environment Variables:

- [ ] `DJANGO_SECRET_KEY` (generate a new one)
- [ ] `DJANGO_DEBUG=false`
- [ ] `DJANGO_ALLOWED_HOSTS` (include .vercel.app domain)
- [ ] `CORS_ALLOWED_ORIGINS`
- [ ] `DATABASE_URL` (PostgreSQL connection string)
- [ ] `REDIS_URL` (Redis connection string)
- [ ] `REDIS_HOST`, `REDIS_PORT`, `REDIS_DB`, `REDIS_PASSWORD`
- [ ] `CLOUDINARY_CLOUD_NAME`
- [ ] `CLOUDINARY_API_KEY`
- [ ] `CLOUDINARY_API_SECRET`
- [ ] `BACKEND_DOMAIN`
- [ ] `EMAIL_BACKEND`, `EMAIL_HOST`, `EMAIL_PORT`, etc.
- [ ] `DEFAULT_FROM_EMAIL`
- [ ] `OTP_EXPIRY_MINUTES`
- [ ] `DJANGO_SETTINGS_MODULE=config.settings.production`

## First Deployment

1. [ ] Commit and push all changes
2. [ ] Go to Vercel Dashboard
3. [ ] Click "Add New" → "Project"
4. [ ] Select your repository
5. [ ] Configure environment variables
6. [ ] Click "Deploy"
7. [ ] Monitor build logs
8. [ ] Test the deployment

## Post-Deployment

- [ ] Test API endpoints
- [ ] Check admin panel (`/admin/`)
- [ ] Test authentication
- [ ] Verify static files loading
- [ ] Check error logs
- [ ] Test file uploads (via Cloudinary)
- [ ] Verify email sending (if applicable)
- [ ] Test WebSocket connections (if using Channels)

## Performance & Monitoring

- [ ] Set up error tracking (Sentry)
- [ ] Set up performance monitoring
- [ ] Configure application logging
- [ ] Set up uptime monitoring
- [ ] Check cold start times

## Common Issues

If deployment fails, check:
- [ ] Build logs for errors
- [ ] Environment variables are set
- [ ] Database connection string is correct
- [ ] All Python dependencies are in requirements.txt
- [ ] `manage.py` can be found (PATH issues)
- [ ] Migrations pass without errors

## Database Migrations

To run additional migrations after initial deployment:

```bash
# Pull environment
vercel env pull .env.local

# Run migrations
python manage.py migrate

# Or use Vercel CLI to run commands (if available)
vercel env run "python manage.py migrate"
```

## Rollback

If needed, rollback to previous version:
1. Go to Vercel Dashboard
2. Select the project
3. Go to "Deployments"
4. Find the previous stable deployment
5. Click the three dots → "Promote to Production"

## Important Notes

⚠️ **Vercel Limitations:**
- Function timeout: 60 sec (free) / 900 sec (pro)
- No persistent file storage
- Stateless functions (no persistent memory)
- Consider these when using Channels/Celery

For more details, see [VERCEL_DEPLOYMENT.md](VERCEL_DEPLOYMENT.md)
