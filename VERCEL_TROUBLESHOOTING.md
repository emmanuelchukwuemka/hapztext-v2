# Vercel Deployment Troubleshooting Guide

This guide helps resolve common issues when deploying Django to Vercel.

## Build Issues

### Issue: "Build failed with exit code 1"

**Check build logs:**
```bash
vercel logs <your-project-url>
```

**Common causes:**

#### 1. Missing Python version specification
**Error**: `Error: Python 3.x is required`

**Solution**: Verify `vercel.json`:
```json
{
  "python": {
    "version": "3.12"
  }
}
```

#### 2. Dependencies not installing
**Error**: `ERROR: Could not find a version that satisfies the requirement...`

**Solutions**:
- [ ] Verify `requirements.txt` and `requirements-prod.txt` are valid
- [ ] Check for version conflicts between packages
- [ ] Try locally: `pip install -r requirements-prod.txt`
- [ ] Update requirements with: `pip freeze > requirements.txt` (after testing)

#### 3. Build script fails
**Error**: `build.sh: command not found` or permission denied

**Solution**:
```bash
# Make build.sh executable
chmod +x build.sh

# Commit changes
git add build.sh
git commit -m "Make build.sh executable"
git push
```

#### 4. Database migrations fail during build
**Error**: `django.db.utils.OperationalError`

**This is expected** - The database may not be accessible during build.

**Solution**: Migrations fail gracefully in `build.sh`. They will run on first request.

---

## Runtime Issues

### Issue: "502 Bad Gateway" or "503 Service Unavailable"

**Cause**: Application error during request handling

**Debug:**
```bash
# View real-time logs
vercel logs <url> --follow

# Filter for errors
vercel logs <url> --query error

# SSH into production
vercel ssh prod
```

**Common causes:**

#### 1. ModuleNotFoundError
**Error**: `ModuleNotFoundError: No module named 'somemodule'`

**Solutions**:
- [ ] Add missing module to `requirements.txt` or `requirements-prod.txt`
- [ ] Verify spelling exactly matches import statement
- [ ] Optional: Use `pip show <modules>` to verify installed locally

**Example**:
```bash
pip install cloudinary
pip freeze | grep -i cloudinary >> requirements-prod.txt
git push && vercel --prod
```

#### 2. ImportError in settings
**Error**: `ImportError: cannot import name 'X' from 'module'`

**Solution**: Check imports in Django settings:
- [ ] `config/settings/base.py`
- [ ] `config/settings/production.py`
- [ ] `config/asgi.py`
- [ ] `api/index.py`

#### 3. Django not initialized
**Error**: `django.core.exceptions.ImproperlyConfigured`

**Solution**: Verify environment variables:
```bash
# In Vercel dashboard, check:
DJANGO_SETTINGS_MODULE=config.settings.production
PYTHONUNBUFFERED=1
PYTHONDONTWRITEBYTECODE=1
```

---

## Connection Issues

### Issue: Database connection timeout

**Error**: `FATAL: remaining connection slots are reserved for non-replication superuser connections`
or `could not connect to server: Connection timed out`

**Causes & Solutions**:

1. **Database not accessible from Vercel**
   - [ ] Check database provider's IP whitelist
   - [ ] Add Vercel IPs or allow all: `0.0.0.0/0`
   - [ ] Verify database is running and accepting connections

2. **Wrong DATABASE_URL**
   - [ ] Verify connection string format:
     ```
     postgresql://user:password@host:5432/dbname
     ```
   - [ ] Check no special characters: encode them as `%XX`
   - [ ] Example: `password@123` → `password%40123`

3. **Connection pool exhausted**
   - [ ] Reduce `CONN_MAX_AGE` in production settings:
     ```python
     CONN_MAX_AGE = 10  # Down from 300
     ```
   - [ ] Increase database connection limit
   - [ ] Use connection pooling (Railway, Supabase, Neon have this)

4. **Network timeout**
   - [ ] Check database provider's firewall logs
   - [ ] Try from local machine with same connection string
   - [ ] If local works but Vercel doesn't, issue is likely IP whitelist

**Test connection locally:**
```bash
# Temporary test - in your terminal
export DATABASE_URL="postgresql://user:password@host:5432/dbname"
python manage.py migrate --noinput
```

### Issue: Redis connection timeout

**Error**: `redis.exceptions.ConnectionError`

**Solutions**:

1. **Verify REDIS_URL**
   ```bash
   # Format check
   redis://[:password@]host:port[/db]
   
   # Example with password
   redis://:mypassword@redis-host.upstash.io:36379
   ```

2. **Check environment variables**
   - [ ] All of these must match:
     - `REDIS_URL` (full URL)
     - `REDIS_HOST` (hostname)
     - `REDIS_PORT` (typically 6379 or custom)
     - `REDIS_PASSWORD` (if required)
     - `REDIS_DB` (typically 0)

3. **Provider firewalls**
   - [ ] Add Vercel IP ranges to Redis provider whitelist
   - [ ] Upstash: Auto-whitelists all IPs ✅
   - [ ] Redis Cloud: Add IP addresses
   - [ ] Custom server: Check firewall rules

4. **Test locally**:
   ```bash
   # Test connection
   redis-cli -u $REDIS_URL ping
   # Should return: PONG
   ```

### Issue: Cloudinary connection issues

**Error**: `cloudinary.exceptions.Error` or `FORBIDDEN`

**Solutions**:

1. **Verify credentials**
   ```bash
   # Check in Vercel environment:
   CLOUDINARY_CLOUD_NAME=your-cloud-name
   CLOUDINARY_API_KEY=your-api-key
   CLOUDINARY_API_SECRET=your-api-secret
   ```

2. **Test locally**
   ```python
   import cloudinary
   print(cloudinary.config())
   ```

3. **Permissions issue**
   - [ ] Go to Cloudinary dashboard
   - [ ] Settings → Security → Restrict API key to specific actions
   - [ ] Ensure "Uploads" is allowed

---

## Configuration Issues

### Issue: "ALLOWED_HOSTS" error (400 Bad Request)

**Error**: `Invalid HTTP_HOST header: 'yoursite.com'. You may need to add 'yoursite.com' to ALLOWED_HOSTS`

**Cause**: The domain in request doesn't match ALLOWED_HOSTS

**Solution**:
1. **Update DJANGO_ALLOWED_HOSTS**:
   ```bash
   # In Vercel environment variables:
   DJANGO_ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com,yourproject.vercel.app
   ```

2. **Or make it permissive (for testing only)**:
   ```bash
   DJANGO_ALLOWED_HOSTS=*
   ```

3. **Redeploy**:
   ```bash
   git commit -m "Update ALLOWED_HOSTS"
   git push
   # or
   vercel --prod
   ```

### Issue: CORS errors in browser

**Error**: `Access to XMLHttpRequest blocked by CORS policy`

**Solution**:
1. **Update CORS_ALLOWED_ORIGINS**:
   ```bash
   # In Vercel environment:
   CORS_ALLOWED_ORIGINS=https://frontend-domain.com,https://www.frontend-domain.com
   ```

2. **Include protocol** (https://, not just domain)

3. **Don't use wildcard** (`*`) if credentials are involved

4. **Verify middleware**:
   ```python
   # config/settings/base.py - check MIDDLEWARE:
   "corsheaders.middleware.CorsMiddleware",  # Must be first
   ```

### Issue: Static files returning 404

**Error**: CSS/JS files return 404 Not Found

**Check build logs:**
```bash
vercel logs <url> | grep "collectstatic"
```

**Solutions**:

1. **Verify build script runs collectstatic**
   ```bash
   # build.sh should contain:
   python manage.py collectstatic --noinput --clear
   ```

2. **Check staticfiles directory created**
   ```bash
   # After local build
   ls -la staticfiles/
   ```

3. **Verify WhiteNoise middleware**
   ```python
   # MIDDLEWARE should include:
   "whitenoise.middleware.WhiteNoiseMiddleware",
   ```

4. **Check vercel.json routes**
   ```json
   {
     "routes": [
       {
         "src": "/static/(.*)",
         "dest": "/staticfiles/$1"
       }
     ]
   }
   ```

---

## WebSocket/Real-Time Issues

### Issue: WebSocket connections fail or timeout

**Error**: `WebSocket connection to 'wss://...' failed`
or `Timeout waiting for WebSocket upgrade`

**Cause**: Vercel functions have execution timeouts (60-900 seconds)

**Status**: ⚠️ WebSockets have limited support on Vercel

**Solutions**:

**Option 1: Disable WebSockets (if not critical)**
```python
# config/settings/production.py
# Remove "daphne" and "channels" from INSTALLED_APPS
INSTALLED_APPS = [
    app for app in INSTALLED_APPS 
    if app not in ["daphne", "channels"]
]
```

**Option 2: Use external service**
- Pusher (https://pusher.com)
- Socket.io
- Firebase Realtime
- AWS AppSync

**Option 3: Polling instead of WebSockets**
- Client polls `/api/v1/messages/?since=<timestamp>`
- Less efficient but works on Vercel

---

## Background Task Issues

### Issue: Celery tasks not running

**Cause**: Vercel doesn't have persistent processes for Celery workers

**Status**: ⚠️ Celery won't work as-is on Vercel

**Solutions**:

**Option 1: Use Vercel Cron Jobs**
```json
{
  "crons": [{
    "path": "/api/v1/tasks/cleanup",
    "schedule": "0 2 * * *"
  }]
}
```

**Option 2: External Celery broker + separate worker**
- Keep Celery but run worker elsewhere:
  - Railway
  - Render
  - AWS Lambda
  - Heroku

**Option 3: Disable Celery**
```python
# If not critical, remove from production:
# Remove from INSTALLED_APPS
# Remove from MIDDLEWARE
```

---

## Performance Issues

### Issue: Requests timing out (504)

**Error**: `FUNCTION_INVOCATION_TIMEOUT`

**Cause**: Function execution exceeded time limit (60s standard plan)

**Solutions**:

1. **Optimize database queries**
   ```python
   # Use select_related for foreign keys
   users = User.objects.select_related('profile').all()
   
   # Use prefetch_related for reverse relations
   posts = Post.objects.prefetch_related('comments').all()
   
   # Use only/defer to limit fields
   users = User.objects.only('id', 'email').all()
   ```

2. **Add caching**
   ```python
   from django.views.decorators.cache import cache_page
   
   @cache_page(60 * 5)  # Cache for 5 minutes
   def my_view(request):
       # This view will be cached
       return Response(data)
   ```

3. **Move slow operations**
   - Use background jobs externally
   - Pre-compute heavy calculations
   - Use lazy loading where appropriate

4. **Upgrade Vercel plan**
   - Pro plan: Longer execution time
   - Enterprise: Customizable limits

### Issue: Cold starts taking too long

**Observation**: First request after deployment takes 10+ seconds

**This is normal** - Django has startup overhead

**Mitigations**:
1. Split code into smaller functions in `api/` folder
2. Use connection pooling for database
3. Minimize imports in `api/index.py`
4. Consider caching imports with decorators

---

## Email Issues

### Issue: Emails not sending

**Error**: `SMTPAuthenticationError` or `SMTPServerDisconnected`

**Solutions**:

1. **Verify SMTP settings**
   ```bash
   # In Vercel environment:
   EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
   EMAIL_HOST=smtp.gmail.com
   EMAIL_PORT=587
   EMAIL_USE_TLS=true
   EMAIL_HOST_USER=your-email@gmail.com
   EMAIL_HOST_PASSWORD=your-app-specific-password
   ```

2. **Gmail specifics** (if using Gmail)
   - [ ] Use App Password, not regular password
   - [ ] 2FA must be enabled
   - [ ] Create at: https://myaccount.google.com/apppasswords
   - [ ] Don't use `%` in password (use URL encoding if needed)

3. **Test locally**
   ```bash
   python manage.py shell
   >>> from django.core.mail import send_mail
   >>> send_mail("Test", "Body", "from@example.com", ["to@example.com"])
   1  # Should return 1 if successful
   ```

4. **Check Vercel logs**
   ```bash
   vercel logs <url> | grep -i email
   ```

---

## Environment Variable Issues

### Issue: Variables not available in application

**Error**: `KeyError` when accessing `os.getenv()`

**Solutions**:

1. **Verify variable is set**
   ```bash
   # List all env vars
   vercel env pull
   # Should create .env file with all variables
   ```

2. **Check case sensitivity**
   ```bash
   # These are different:
   MY_VAR
   my_var
   ```

3. **Redeploy after adding variables**
   ```bash
   # Variables don't take effect until redeploy
   vercel --prod
   ```

4. **Check variable isn't overridden**
   ```bash
   # In vercel.json, env section can override:
   "env": {
     "DJANGO_DEBUG": "false"  // This takes precedence
   }
   ```

---

## Deployment Issues

### Issue: "Permission denied" when deploying

**Error**: `Error: EACCES: permission denied`

**Solution**:
```bash
# Re-authenticate with Vercel
vercel logout
vercel login

# Then deploy
vercel --prod
```

### Issue: Deployment stuck in "Building" state

**Solution**:
1. Cancel deployment in Vercel dashboard: Deployments → Cancel
2. Wait 5 minutes
3. Try again: `vercel --prod`

### Issue: Changes not appearing after deploy

**Solutions**:
1. **Is it actually deployed?**
   ```bash
   vercel ls  # Check latest deployment status
   vercel logs <url>  # View build output
   ```

2. **Cache issues**
   - [ ] Hard refresh browser: Ctrl+Shift+R
   - [ ] Clear browser cache
   - [ ] Check CDN cache: Vercel dashboard → Deployments → Clear Cache

3. **Wrong branch deployed**
   - [ ] Verify branch in Vercel dashboard: Settings → Git
   - [ ] Deploy from specific branch: `vercel --prod --target main`

4. **Environment variables changed**
   - [ ] Changes require redeploy to take effect
   - [ ] Trigger rebuild: Vercel dashboard → Deployments → Redeploy

---

## Debugging Strategies

### 1. View Detailed Logs

```bash
# Real-time logs
vercel logs <url> --follow

# Specific time range
vercel logs <url> --since 1h

# Search for keywords
vercel logs <url> --query "error"

# Get raw output
vercel logs <url> > debug.log
```

### 2. SSH Into Production (Pro+ Plans)

```bash
# Connect to running server
vercel ssh prod

# Inside the container, you can:
python manage.py shell
python manage.py dbshell
env | grep DJANGO
```

### 3. Create Debug Endpoint

```python
# Temporary - DELETE AFTER DEBUGGING
@api_view(['GET'])
def debug_info(request):
    import sys
    import os
    
    return Response({
        'python_version': sys.version,
        'django_settings_module': os.getenv('DJANGO_SETTINGS_MODULE'),
        'database': settings.DATABASES['default'],
        'installed_apps': list(settings.INSTALLED_APPS),
        'middleware': list(settings.MIDDLEWARE),
    })

# Add to urls.py temporarily
path('debug/', debug_info),  # DELETE AFTER
```

### 4. Test Configuration Locally

```bash
# Mirror production locally
export DJANGO_SETTINGS_MODULE=config.settings.production
export DATABASE_URL="<your-postgres-url>"
python manage.py check --deploy

# Run with production settings
python manage.py collectstatic --noinput
gunicorn config.wsgi:application
```

---

## Prevention Tips

1. **Always test locally first**
   ```bash
   python manage.py check --deploy
   python manage.py test
   ```

2. **Use same Python version locally and on Vercel**
   - Local: `python --version`
   - Vercel: `"python": {"version": "3.12"}`

3. **Keep requirements up-to-date**
   ```bash
   pip install --upgrade -r requirements-prod.txt
   pip freeze > requirements-prod.txt
   ```

4. **Regular backup strategy**
   - Database backups: Enable in database provider
   - Git commits: Regular pushes
   - Test recovery: Actually restore from backup

5. **Monitor production**
   - Check logs regularly
   - Set up error notifications
   - Monitor database size and connections

---

## Still Having Issues?

1. **Search similar issues**: https://github.com/vercel/vercel/discussions
2. **Django Docs**: https://docs.djangoproject.com/
3. **Vercel Docs**: https://vercel.com/docs
4. **Stack Overflow**: Tag with `django` + `vercel`

---

**Last Updated**: March 2026
