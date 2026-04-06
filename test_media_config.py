#!/usr/bin/env python
"""
Quick test script to verify media file serving configuration
Run this on your VPS to check if media files are accessible
"""

import os
import sys
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.production')

import django
django.setup()

from django.conf import settings

def test_media_configuration():
    print("=" * 60)
    print("MEDIA CONFIGURATION TEST")
    print("=" * 60)
    
    # Test 1: Check settings
    print("\n1. Django Settings:")
    print(f"   DEBUG: {settings.DEBUG}")
    print(f"   MEDIA_URL: {settings.MEDIA_URL}")
    print(f"   MEDIA_ROOT: {settings.MEDIA_ROOT}")
    print(f"   USE_CLOUDINARY: {getattr(settings, 'USE_CLOUDINARY', 'Not set')}")
    print(f"   SERVE_MEDIA_IN_PRODUCTION: {getattr(settings, 'SERVE_MEDIA_IN_PRODUCTION', False)}")
    
    # Test 2: Check storage backend
    print("\n2. Storage Backend:")
    try:
        from django.core.files.storage import default_storage
        print(f"   Default Storage: {type(default_storage).__name__}")
        print(f"   Storage Location: {default_storage.location if hasattr(default_storage, 'location') else 'N/A'}")
    except Exception as e:
        print(f"   Error getting storage: {e}")
    
    # Test 3: Check if Cloudinary is configured
    print("\n3. Cloudinary Configuration:")
    if hasattr(settings, 'CLOUDINARY_STORAGE'):
        cloud_name = settings.CLOUDINARY_STORAGE.get('CLOUD_NAME', 'Not set')
        if cloud_name == 'test':
            print("   ⚠️  Using TEST credentials - will use local storage")
        else:
            print(f"   ✓ Cloud Name: {cloud_name}")
            print("   ✓ Cloudinary is active")
    else:
        print("   ✗ Cloudinary not configured")
    
    # Test 4: Check media directory
    print("\n4. Media Directory:")
    media_path = Path(settings.MEDIA_ROOT)
    print(f"   Media Root Exists: {media_path.exists()}")
    if media_path.exists():
        print(f"   Media Root Path: {media_path}")
        
        # List subdirectories
        subdirs = [d.name for d in media_path.iterdir() if d.is_dir()]
        print(f"   Subdirectories: {subdirs}")
        
        # Count files
        files = list(media_path.rglob("*"))
        print(f"   Total Files: {len([f for f in files if f.is_file()])}")
        
        # Show recent files
        print("\n   Recent Files:")
        recent_files = sorted(
            [f for f in files if f.is_file()],
            key=lambda x: x.stat().st_mtime,
            reverse=True
        )[:5]
        
        for file in recent_files:
            rel_path = file.relative_to(media_path)
            size_kb = file.stat().st_size / 1024
            print(f"     - {rel_path} ({size_kb:.1f} KB)")
    else:
        print(f"   ✗ Media directory does not exist: {media_path}")
    
    # Test 5: Check URL patterns
    print("\n5. URL Configuration:")
    from django.urls import get_resolver
    resolver = get_resolver()
    
    # Check if media pattern exists
    url_patterns = []
    def collect_patterns(resolver, prefix=''):
        for pattern in resolver.url_patterns:
            pattern_str = str(pattern.pattern)
            if 'media' in pattern_str.lower():
                url_patterns.append(prefix + pattern_str)
            if hasattr(pattern, 'url_patterns'):
                collect_patterns(pattern, prefix + pattern_str)
    
    collect_patterns(resolver)
    if url_patterns:
        print(f"   ✓ Media URL patterns found: {url_patterns}")
    else:
        print(f"   ✗ No media URL patterns found")
    
    # Test 6: Test file access
    print("\n6. File Access Test:")
    test_file = "cover_pictures/1000783003_j9FFDUS.jpg"
    full_path = media_path / test_file
    
    if full_path.exists():
        print(f"   ✓ Test file exists: {test_file}")
        print(f"   Full path: {full_path}")
        print(f"   File size: {full_path.stat().st_size / 1024:.1f} KB")
        
        # Try to read it
        try:
            with open(full_path, 'rb') as f:
                content = f.read(10)
                print(f"   ✓ File is readable (first bytes: {content.hex()})")
        except Exception as e:
            print(f"   ✗ Cannot read file: {e}")
    else:
        print(f"   ✗ Test file not found: {test_file}")
        print(f"      Expected at: {full_path}")
    
    # Test 7: Generate test URL
    print("\n7. Test URL Generation:")
    backend_domain = getattr(settings, 'BACKEND_DOMAIN', 'http://localhost:8000')
    test_url = f"{backend_domain}{settings.MEDIA_URL}{test_file}"
    print(f"   Expected URL: {test_url}")
    print(f"\n   Test with curl:")
    print(f"   curl -I {test_url}")
    
    print("\n" + "=" * 60)
    print("TEST COMPLETE")
    print("=" * 60)
    
    # Recommendations
    print("\nRECOMMENDATIONS:")
    
    if not getattr(settings, 'USE_CLOUDINARY', False):
        print("  ⚠️  Not using Cloudinary - files stored locally on VPS")
        print("     Consider using Cloudinary for production (see MEDIA_FIX_GUIDE.md)")
    
    if not media_path.exists():
        print(f"  ✗ Create media directory: mkdir -p {media_path}")
    
    if not full_path.exists():
        print(f"  ✗ Upload file missing: {test_file}")
        print("     This file was referenced by Flutter app but not found on server")

if __name__ == "__main__":
    test_media_configuration()
