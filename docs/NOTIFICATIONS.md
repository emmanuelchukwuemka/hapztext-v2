# Hapztext Notifications API Documentation

## Overview

The notifications system provides real-time in-app notifications for user interactions using Server-Sent Events (SSE). The system is built on django-eventstream with Redis as the message broker.

### Key Features
- Real-time notification delivery via SSE
- Automatic notifications for: new posts, replies, follow requests, follow acceptances
- User-specific notification preferences
- Unread notification tracking
- Pagination support for notification history
- Secure, authenticated SSE channels

---

## Base URL

All notification endpoints are prefixed with `/api/v1/notifications/`.

---

## 1. Server-Sent Events (SSE) Endpoint
### 1.1. Real-time Notifications Stream

Establishes a persistent SSE connection for receiving real-time notifications.

- **Endpoint:** `/api/v1/notifications/stream/`
- **HTTP Method:** `POST`
- **Description:** Creates an authenticated SSE connection for real-time notifications
- **Authentication:** Required (Bearer Token in Header: `Authorization: Bearer <auth_token>`)
- **Request Headers:**
  ```
  Accept: text/event-stream
  Authorization: Bearer <auth_token>
  Cache-Control: no-cache
  ```

- **✅ Success Response:** Continuous event stream with two event types

#### Event Type 1: `notification`
Sent when a new notification is created for the user.

```
event: notification
data: {
  "id": "notif_abc123",
  "type": "post_created",
  "message": "New post from @username",
  "data": {
    "post_id": "post_xyz789",
    "post_preview": "Check out this amazing sunset..."
  },
  "sender_id": "user_456",
  "created_at": "2025-01-15T10:30:00Z",
  "is_read": false,
  "timestamp": "2025-01-15T10:30:00Z",
  "channel": "notifications-user_123",
  "user_id": "user_123"
}
```

#### Event Type 2: `unread_count_update`
Sent when the unread notification count changes.

```
event: unread_count_update
data: {
  "unread_count": 5,
  "user_id": "user_123"
}
```

### 1.2. SSE Connection Details

**Channel Naming Convention:**
```
notifications-{user_id}
```

**Security:**
- Each user can only connect to their own channel
- Enforced by `AuthenticatedChannelManager`
- Unauthorized access attempts are rejected

**Connection Lifecycle:**
1. Client sends POST request to `/api/v1/notifications/stream/`
2. Server validates authentication token
3. Server verifies user has access to their channel
4. SSE connection established
5. Events pushed to client in real-time
6. Connection maintained with periodic heartbeats
7. Auto-reconnect on disconnection

---

## 2. Notification Management Endpoints

### 2.1. Get User Notifications

Fetch paginated list of user notifications with optional filtering.

- **Endpoint:** `/api/v1/notifications/{page}/{page_size}/`
- **HTTP Method:** `GET`
- **Description:** Retrieves user's notifications with pagination
- **Authentication:** Required (Bearer Token)

#### URL Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `page` | integer | Yes | Page number (starts from 1) |
| `page_size` | integer | Yes | Notifications per page (1-100) |

#### Query Parameters
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `unread_only` | boolean | No | `false` | If `true`, only returns unread notifications |

#### Example Request
```http
GET /api/v1/notifications/1/20/?unread_only=true
Authorization: Bearer <auth_token>
```

#### Success Response (Status: 200 OK)
```json
{
  "success": true,
  "message": "Notifications fetched successfully.",
  "data": {
    "result": [
      {
        "id": "notif_abc123",
        "recipient_id": "user_123",
        "sender_id": "user_456",
        "notification_type": "post_created",
        "message": "New post from @username",
        "data": {
          "post_id": "post_xyz789",
          "post_preview": "Check out this amazing sunset..."
        },
        "is_read": false,
        "created_at": "2025-01-15T10:30:00Z",
        "updated_at": "2025-01-15T10:30:00Z"
      },
      {
        "id": "notif_def456",
        "recipient_id": "user_123",
        "sender_id": "user_789",
        "notification_type": "follow",
        "message": "@johndoe followed you",
        "is_read": false,
        "created_at": "2025-01-15T09:15:00Z",
        "updated_at": "2025-01-15T09:15:00Z"
      }
    ],
    "previous_notifications_data": null,
    "next_notifications_data": "/api/v1/notifications/2/20/",
    "unread_count": 5
  },
  "status_code": 200
}
```

#### Error Response (Status: 400 Bad Request)
```json
{
  "success": false,
  "message": "Validation error",
  "errors": {
    "detail": "Page size must be between 1 and 100."
  },
  "status_code": 400
}
```

---

### 2.2. Mark Notifications as Read

Mark specific notifications or all notifications as read.

- **Endpoint:** `/api/v1/notifications/mark-read/`
- **HTTP Method:** `POST`
- **Description:** Updates notification read status
- **Authentication:** Required (Bearer Token)

#### Request Body

**Option 1: Mark specific notifications as read**
```json
{
  "notification_ids": ["notif_abc123", "notif_def456", "notif_ghi789"]
}
```

**Option 2: Mark all notifications as read**
```json
{
  "notification_ids": []
}
```
or simply omit the field:
```json
{}
```

#### Success Response (Status: 200 OK)
```json
{
  "success": true,
  "message": "Notifications marked as read successfully.",
  "data": {},
  "status_code": 200
}
```

**Note:** After marking notifications as read, an `unread_count_update` event is automatically sent via SSE to update the unread count in real-time.

---

## 3. Notification Preferences Endpoints

### 3.1. Get Notification Preferences

Retrieve current user's notification preferences.

- **Endpoint:** `/api/v1/notifications/preferences/`
- **HTTP Method:** `GET`
- **Description:** Fetches user's notification settings
- **Authentication:** Required (Bearer Token)
- **Request Body:** None

#### Success Response (Status: 200 OK)
```json
{
  "success": true,
  "message": "Notification preferences fetched successfully.",
  "data": {
    "id": "pref_xyz123",
    "user_id": "user_123",
    "post_notifications_enabled": true,
    "follow_notifications_enabled": true,
    "reply_notifications_enabled": true,
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-15T10:30:00Z"
  },
  "status_code": 200
}
```

**Note:** If preferences don't exist for the user, they are automatically created with default values (all notifications enabled).

---

### 3.2. Update Notification Preferences

Modify notification preferences for the current user.

- **Endpoint:** `/api/v1/notifications/preferences/update/`
- **HTTP Method:** `PUT`
- **Description:** Updates user's notification settings
- **Authentication:** Required (Bearer Token)

#### Request Body
All fields are optional. Only include fields you want to update.

```json
{
  "post_notifications_enabled": false,
  "follow_notifications_enabled": true,
  "reply_notifications_enabled": true
}
```

#### Preference Fields
| Field | Type | Description |
|-------|------|-------------|
| `post_notifications_enabled` | boolean | Enable/disable notifications for new posts from followed users |
| `follow_notifications_enabled` | boolean | Enable/disable notifications for follows |
| `reply_notifications_enabled` | boolean | Enable/disable notifications for replies to user's posts |

#### Success Response (Status: 200 OK)
```json
{
  "success": true,
  "message": "Notification preferences updated successfully.",
  "data": {
    "id": "pref_xyz123",
    "user_id": "user_123",
    "post_notifications_enabled": false,
    "follow_notifications_enabled": true,
    "reply_notifications_enabled": true,
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-15T10:35:00Z"
  },
  "status_code": 200
}
```

---

## 4. Notification Types

### 4.1. Notification Type Definitions

| Type | Trigger Event | Message Format | Data Fields |
|------|--------------|----------------|-------------|
| `post_created` | User creates a new post | "New post from @{username}" | `post_id`, `post_preview` |
| `post_reply` | User replies to a post | "@{username} replied to your post" | `original_post_id`, `reply_id` |
| `follow` | User follows another user | "@{username} followed you" | Nil |

### 4.2. Notification Creation Logic

**Automatic Triggers:**

1. **New Post Created** → Notify all followers
   - Checks each follower's `post_notifications_enabled` preference
   - Skips notification if preference is disabled

2. **Post Reply** → Notify original post creator
   - Only if replier is different from post creator
   - Checks post creator's `reply_notifications_enabled` preference

3. **Follow Sent** → Notify target user
   - Checks target user's `follow_notifications_enabled` preference

### 4.3. Complete Notification Data Structure

```json
{
  "id": "notif_abc123",
  "recipient_id": "user_123",
  "sender_id": "user_456",
  "notification_type": "post_created|post_reply|follow",
  "message": "Human-readable message",
  "data": {
    // Type-specific data (see table above)
  },
  "is_read": false,
  "created_at": "2025-01-15T10:30:00Z",
  "updated_at": "2025-01-15T10:30:00Z"
}
```

---

## 5. System Architecture

### 5.1. Notification Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    TRIGGERING EVENT                         │
│  (New Post, Follow, Reply, etc.)                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│              CreateNotificationRule                         │
│  1. Check recipient's notification preferences              │
│  2. Create Notification entity                              │
│  3. Save to database                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│             NotificationDispatcher                          │
│  1. Format notification data                                │
│  2. Call SSENotificationService                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│          SSENotificationService                             │
│  1. Get user channel: notifications-{user_id}               │
│  2. Publish to Redis via django-eventstream                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                  REDIS (PubSub)                             │
│  Channel: notifications-{user_id}                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│            DAPHNE (ASGI Server)                             │
│  django-eventstream processes Redis events                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│              CLIENT (Browser)                               │
│  EventSource connection receives notification               │
└─────────────────────────────────────────────────────────────┘
```

### 5.2. Channel Security

**AuthenticatedChannelManager Implementation:**

```python
class AuthenticatedChannelManager(DefaultChannelManager):
    def can_read_channel(self, user, channel):
        if channel.startswith("notifications-"):
            # Reject anonymous users
            if not user or user.is_anonymous:
                return False
            
            # Extract user_id from channel name
            channel_user_id = channel.replace("notifications-", "")
            
            # User can only read their own channel
            return str(user.id) == channel_user_id
        
        return super().can_read_channel(user, channel)
```

**Security Features:**
- Authentication required for all channels
- Users can only access their own notification channel
- Channel name validation prevents injection attacks
- Anonymous users automatically rejected

---

## 6. Frontend Integration Guide

### 6.1. Establishing SSE Connection

```javascript
// Create EventSource connection
const connectToNotifications = (authToken, userId) => {
  const eventSource = new EventSource(
    `/api/v1/notifications/stream/`,
    {
      headers: {
        'Authorization': `Bearer ${authToken}`
      }
    }
  );

  // Handle new notification events
  eventSource.addEventListener('notification', (event) => {
    const notification = JSON.parse(event.data);
    console.log('New notification:', notification);
    
    // Update UI
    displayNotification(notification);
    addToNotificationList(notification);
  });

  // Handle unread count updates
  eventSource.addEventListener('unread_count_update', (event) => {
    const data = JSON.parse(event.data);
    console.log('Unread count:', data.unread_count);
    
    // Update badge
    updateNotificationBadge(data.unread_count);
  });

  // Handle connection errors
  eventSource.addEventListener('error', (event) => {
    console.error('SSE connection error:', event);
    // Implement exponential backoff reconnection
    reconnectWithBackoff();
  });

  return eventSource;
};
```

### 6.2. Fetching Notification History

```javascript
// Fetch all notifications (paginated)
const fetchNotifications = async (page = 1, pageSize = 20) => {
  const response = await fetch(
    `/api/v1/notifications/${page}/${pageSize}/`,
    {
      headers: {
        'Authorization': `Bearer ${authToken}`
      }
    }
  );
  
  const data = await response.json();
  return data.data; // Contains result, pagination links, unread_count
};

// Fetch only unread notifications
const fetchUnreadNotifications = async (page = 1, pageSize = 20) => {
  const response = await fetch(
    `/api/v1/notifications/${page}/${pageSize}/?unread_only=true`,
    {
      headers: {
        'Authorization': `Bearer ${authToken}`
      }
    }
  );
  
  return await response.json();
};
```

### 6.3. Marking Notifications as Read

```javascript
// Mark specific notifications as read
const markNotificationsRead = async (notificationIds) => {
  await fetch('/api/v1/notifications/mark-read/', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${authToken}`
    },
    body: JSON.stringify({
      notification_ids: notificationIds
    })
  });
};

// Mark all notifications as read
const markAllNotificationsRead = async () => {
  await fetch('/api/v1/notifications/mark-read/', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${authToken}`
    },
    body: JSON.stringify({
      notification_ids: []  // Empty array marks all as read
    })
  });
};
```

### 6.4. Managing Notification Preferences

```javascript
// Get current preferences
const getNotificationPreferences = async () => {
  const response = await fetch('/api/v1/notifications/preferences/', {
    headers: {
      'Authorization': `Bearer ${authToken}`
    }
  });
  
  return await response.json();
};

// Update preferences
const updateNotificationPreferences = async (preferences) => {
  await fetch('/api/v1/notifications/preferences/update/', {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${authToken}`
    },
    body: JSON.stringify({
      post_notifications_enabled: preferences.posts,
      follow_notifications_enabled: preferences.follows,
      reply_notifications_enabled: preferences.replies
    })
  });
};
```

### 6.5. Complete React Hook Example

```javascript
import { useState, useEffect } from 'react';

const useNotifications = (authToken, userId) => {
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [eventSource, setEventSource] = useState(null);

  useEffect(() => {
    // Establish SSE connection
    const es = new EventSource(`/api/v1/notifications/stream/`);

    es.addEventListener('notification', (event) => {
      const notification = JSON.parse(event.data);
      setNotifications(prev => [notification, ...prev]);
      setUnreadCount(prev => prev + 1);
    });

    es.addEventListener('unread_count_update', (event) => {
      const data = JSON.parse(event.data);
      setUnreadCount(data.unread_count);
    });

    setEventSource(es);

    // Cleanup on unmount
    return () => {
      es.close();
    };
  }, [authToken, userId]);

  const markAsRead = async (notificationIds) => {
    await fetch('/api/v1/notifications/mark-read/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
      },
      body: JSON.stringify({ notification_ids: notificationIds })
    });
  };

  return {
    notifications,
    unreadCount,
    markAsRead,
    isConnected: eventSource !== null
  };
};

export default useNotifications;
```

---

## 7. Error Handling

### 7.1. Common Error Responses

#### Authentication Error (401)
```json
{
  "success": false,
  "message": "Authentication required",
  "errors": {
    "detail": "Authentication credentials were not provided."
  },
  "status_code": 401
}
```

#### Validation Error (400)
```json
{
  "success": false,
  "message": "Validation error",
  "errors": {
    "detail": "Page must be greater than 0."
  },
  "status_code": 400
}
```

#### Permission Denied (403)
```json
{
  "success": false,
  "message": "Permission denied",
  "errors": {
    "detail": "You do not have permission to access this channel."
  },
  "status_code": 403
}
```

### 7.2. SSE Error Handling

```javascript
eventSource.addEventListener('error', (event) => {
  console.error('SSE connection error');
  
  // Implement exponential backoff
  let retryDelay = 1000; // Start with 1 second
  const maxRetryDelay = 30000; // Max 30 seconds
  
  const reconnect = () => {
    setTimeout(() => {
      console.log(`Reconnecting in ${retryDelay}ms...`);
      // Recreate connection
      connectToNotifications(authToken, userId);
      
      // Increase delay for next retry
      retryDelay = Math.min(retryDelay * 2, maxRetryDelay);
    }, retryDelay);
  };
  
  reconnect();
});
```

---

### 8.2. Rate Limiting

**Current Limits:**
- Authenticated users: 10 requests/minute
- SSE connections: 1 per user

---

## 9. Configuration

### 9.1. Environment Variables

```bash
# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=your_redis_password

# SSE Configuration (in settings.py)
EVENTSTREAM_REDIS = {
    'host': REDIS_HOST,
    'port': REDIS_PORT,
    'db': REDIS_DB,
    'password': REDIS_PASSWORD,
}

EVENTSTREAM_CHANNELMANAGER_CLASS = \
    'apps.infrastructure.notifications.channels.AuthenticatedChannelManager'

EVENTSTREAM_STORAGE_CLASS = 'django_eventstream.storage.DjangoModelStorage'
```

### 9.2. CORS Configuration for SSE

```python
# Ensure CORS allows SSE connections
CORS_ALLOWED_ORIGINS = ['http://localhost:3000', 'https://yourapp.com']
CORS_ALLOW_CREDENTIALS = True
EVENTSTREAM_ALLOW_ORIGINS = CORS_ALLOWED_ORIGINS
EVENTSTREAM_ALLOW_CREDENTIALS = True
EVENTSTREAM_ALLOW_HEADERS = 'Authorization'
```

---

## 10. Testing

### 10.1. Testing SSE Connection

```bash
# Using curl
curl -N -H "Authorization: Bearer <your_token>" \
  -H "Accept: text/event-stream" \
  -X POST http://localhost:8000/api/v1/notifications/stream/
```

### 10.2. Testing Notification Creation

```bash
# Create a post (triggers notifications to followers)
curl -X POST http://localhost:8000/api/v1/posts/ \
  -H "Authorization: Bearer <your_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "post_format": "text",
    "text_content": "Hello, world!"
  }'
```

### 10.3. Testing Mark as Read

```bash
# Mark specific notifications as read
curl -X POST http://localhost:8000/api/v1/notifications/mark-read/ \
  -H "Authorization: Bearer <your_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "notification_ids": ["notif_123", "notif_456"]
  }'

# Mark all as read
curl -X POST http://localhost:8000/api/v1/notifications/mark-read/ \
  -H "Authorization: Bearer <your_token>" \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

**Document Version History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | January 2025 | System | Initial documentation |
| 2.0 | October 2025 | System | Updated to match current codebase implementation |

---

**End of Notifications Documentation**