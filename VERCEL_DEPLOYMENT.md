# Vercel Deployment Guide for HapzText Backend

## Overview
This guide provides instructions for deploying the HapzText Django backend to Vercel.

## Prerequisites
- Vercel account (https://vercel.com)
- Project pushed to GitHub, GitLab, or Bitbucket
- PostgreSQL database (Vercel doesn't provide persistent storage)
- Redis instance (for caching and Celery)
- Cloudinary account (already configured in the project)

## Important Limitations ⚠️

Vercel Serverless Functions have the following constraints:

1. **Function Timeout**
   - Free plan: 60 seconds
   - Pro plan: 900 seconds (15 minutes)
   - Channels/WebSocket connections may timeout

2. **No Persistent Storage**
   - `/app/logs`, `/app/media`, `/app/staticfiles` won't persist between invocations
   - Use Cloudinary (already configured) for media files
   - Use external logging services for logs

3. **Cold Starts**
   - First request may be slow due to function initialization
   - Subsequent requests should be faster

4. **Stateless Architecture**
   - WebSockets via Channels work but have timeout limitations
   - Consider external task queues for Celery

## Environment Variables Required

Set these in your Vercel project settings:

```
DJANGO_SECRET_KEY=your-secret-key-here
DJANGO_DEBUG=false
DJANGO_ALLOWED_HOSTS=yourdomain.com,.vercel.app
CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://yourfrontend.com
DATABASE_URL=postgresql://user:password@host:port/dbname
REDIS_URL=redis://:password@host:port
REDIS_HOST=your-redis-host
REDIS_PORT=your-redis-port
REDIS_DB=0
REDIS_PASSWORD=your-redis-password
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
BACKEND_DOMAIN=yourdomain.com
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=true
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-email-password
DEFAULT_FROM_EMAIL=noreply@hapztext.com
OTP_EXPIRY_MINUTES=10
DJANGO_SETTINGS_MODULE=config.settings.production
```

## Deployment Steps

### 1. Prepare Your Code
```bash
# Ensure all changes are committed
git add .
git commit -m "Prepare for Vercel deployment"
git push
```

### 2. Connect to Vercel
```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel
```

Or use the Vercel Dashboard:
1. Go to https://vercel.com/dashboard
2. Click "Add New" → "Project"
3. Import your GitHub repository
4. Set environment variables
5. Click "Deploy"

### 3. Configure Environment Variables
In Vercel Dashboard:
1. Go to Settings → Environment Variables
2. Add all required variables (see section above)
3. Redeploy after adding variables

### 4. Verify Deployment
```bash
# Check deployment status
vercel status

# View logs
vercel logs <deployment-url>
```

## File Structure

The deployment includes these key files:

- `vercel.json` - Vercel configuration
- `api/index.py` - WSGI handler for Vercel functions
- `build.sh` - Build script for collectstatic and migrations
- `requirements-prod.txt` - Production dependencies (gunicorn, uvicorn)
- `.vercelignore` - Files/folders to exclude from deployment

## Database Migrations

Migrations are automatically run during the build phase. To run additional migrations:

```bash
# Via Vercel CLI
vercel env pull .env.local
python manage.py migrate
```

## Static Files

Static files are:
1. Collected during build (`python manage.py collectstatic`)
2. Compressed by WhiteNoise
3. Served from the `staticfiles/` directory
4. Cached indefinitely with immutable flag

## Troubleshooting

### Issue: 502 Bad Gateway
- Check CloudWatch/application logs
- Verify environment variables are set correctly
- Check database connectivity

### Issue: Static files not loading
- Files must be in static directories or admin
- Run: `python manage.py collectstatic --noinput`
- Clear Vercel cache and redeploy

### Issue: Database connection timeout
- Verify DATABASE_URL is correct
- Check database network permissions
- Ensure connection pooling is configured (dj-database-url handles this)

### Issue: WebSocket connection fails
- Channels work on Vercel but have timeout limits
- Consider using polling as fallback
- Check the CORS and WebSocket configuration

## Monitoring

Recommend setting up:
1. **Error tracking**: Sentry, Rollbar, or similar
2. **Performance monitoring**: New Relic, Datadog
3. **Logging**: CloudWatch, ELK stack, or Papertrail
4. **Uptime monitoring**: StatusPage, Pingdom

## Security Best Practices

1. ✅ Use environment variables for secrets (never commit)
2. ✅ Enable HTTPS (automatic with Vercel)
3. ✅ Use strong SECRET_KEY
4. ✅ Keep dependencies updated
5. ✅ Enable HSTS (configured in production.py)
6. ✅ Use database SSL connections (if supported)

## Alternatives to Vercel

If Vercel limitations are problematic:

- **Heroku** - Traditional platform with persistent storage
- **Railway** - Modern alternative to Heroku
- **Render** - Easy Django deployments
- **PythonAnywhere** - Python-specific hosting
- **AWS/Google Cloud** - More control, more complex
- **DigitalOcean App Platform** - Docker-based deployment

## Additional Resources

- [Vercel Python Runtime Docs](https://vercel.com/docs/runtimes/python)
- [Django Deployment Checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/)
- [Channels Deployment Guide](https://channels.readthedocs.io/en/stable/deploying.html)
- [Celery Deployment Guide](https://docs.celeryproject.org/en/stable/getting-started/brokers/)

## Support

For issues specific to:
- Vercel deployment: Check [Vercel Discord](https://vercel.com/support)
- Django: Consult [Django documentation](https://docs.djangoproject.com/)
- WebSockets: See [Channels documentation](https://channels.readthedocs.io/)
