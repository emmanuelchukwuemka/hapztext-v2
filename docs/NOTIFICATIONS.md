# 🔔 Notifications API Documentation

## Overview

The notifications system provides real-time in-app notifications for user interactions including:
- New posts from followed users
- Replies to user's posts  
- Follow requests and acceptances
- Real-time delivery via Server-Sent Events (SSE)
- Offline notification support

## 🌐 Base URL

All notification endpoints are prefixed with `/api/v1/notifications/`.

---

## 📡 1. Server-Sent Events (SSE) Endpoint

### 1.1. 🔴 Real-time Notifications Stream

- **🔗 Endpoint:** `/stream`
- **📡 HTTP Method:** `POST`
- **📝 Description:** Establishes SSE connection for real-time notifications
- **🔐 Authentication:** Required (Bearer Token in Header: `Authorization: Bearer <auth_token>`)
- **📤 Request Headers:**
  ```
  Accept: text/event-stream
  Authorization: Bearer <auth_token>
  ```
- **✅ Success Response:** Continuous event stream with events:
  - `notification`: New notification received
  - `unread_count_update`: Updated unread notification count
  
- **📋 Example Events:**
  ```
  event: notification
  data: {"id": "abc123", "type": "post_created", "message": "New post from a user you follow", "data": {"post_id": "xyz789"}, "sender_id": "user456", "created_at": "2024-01-15T10:30:00Z", "is_read": false}
  ```

---

## 📋 2. Notification Management Endpoints

### 2.1. 📖 Get User Notifications

- **🔗 Endpoint:** `/api/v1/notifications/{page}/{page_size}/`
- **📡 HTTP Method:** `GET`
- **📝 Description:** Fetches paginated list of user notifications
- **🔐 Authentication:** Required (Bearer Token)
- **🔗 URL Parameters:**
  - `page`: integer (required) - Page number (starts from 1)
  - `page_size`: integer (required) - Number of notifications per page (1-100)
- **🔗 Query Parameters:**
  - `unread_only`: boolean (optional) - Filter to unread notifications only
- **📤 Request Body:** None

- **✅ Success Response (Status: 200 OK):**
  ```json
  {
    "success": true,
    "message": "Notifications fetched successfully.",
    "data": {
      "result": [
        {
          "id": "notification_id_123",
          "recipient_id": "user_123",
          "sender_id": "user_456", 
          "notification_type": "post_created",
          "message": "New post from a user you follow",
          "data": {
            "post_id": "post_789",
            "post_preview": "Check out this amazing sunset..."
          },
          "is_read": false,
          "created_at": "2024-01-15T10:30:00Z",
          "updated_at": "2024-01-15T10:30:00Z"
        }
      ],
      "previous_notifications_data": "/api/v1/notifications/1/10/",
      "next_notifications_data": "/api/v1/notifications/3/10/",
      "unread_count": 5
    },
    "status_code": 200
  }
  ```

### 2.2. ✅ Mark Notifications as Read

- **🔗 Endpoint:** `/api/v1/notifications/mark-read/`
- **📡 HTTP Method:** `POST`
- **📝 Description:** Mark specific notifications or all notifications as read
- **🔐 Authentication:** Required (Bearer Token)
- **📤 Request Body:**
  ```json
  {
    "notification_ids": ["id1", "id2", "id3"]  // Optional: omit to mark all as read
  }
  ```

- **✅ Success Response (Status: 200 OK):**
  ```json
  {
    "success": true,
    "message": "Notifications marked as read successfully.",
    "data": {},
    "status_code": 200
  }
  ```

---

## ⚙️ 3. Notification Preferences Endpoints

### 3.1. 📖 Get Notification Preferences

- **🔗 Endpoint:** `/api/v1/notifications/preferences/`
- **📡 HTTP Method:** `GET`
- **📝 Description:** Get user's notification preferences
- **🔐 Authentication:** Required (Bearer Token)
- **📤 Request Body:** None

- **✅ Success Response (Status: 200 OK):**
  ```json
  {
    "success": true,
    "message": "Notification preferences fetched successfully.",
    "data": {
      "id": "pref_123",
      "user_id": "user_123",
      "post_notifications_enabled": true,
      "follow_notifications_enabled": true,
      "reply_notifications_enabled": true,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    },
    "status_code": 200
  }
  ```

### 3.2. ✏️ Update Notification Preferences

- **🔗 Endpoint:** `/api/v1/notifications/preferences/update/`
- **📡 HTTP Method:** `PUT`
- **📝 Description:** Update user's notification preferences
- **🔐 Authentication:** Required (Bearer Token)
- **📤 Request Body:**
  ```json
  {
    "post_notifications_enabled": false,     // Optional
    "follow_notifications_enabled": true,   // Optional  
    "reply_notifications_enabled": true     // Optional
  }
  ```

- **✅ Success Response (Status: 200 OK):**
  ```json
  {
    "success": true,
    "message": "Notification preferences updated successfully.",
    "data": {
      "id": "pref_123",
      "user_id": "user_123", 
      "post_notifications_enabled": false,
      "follow_notifications_enabled": true,
      "reply_notifications_enabled": true,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T10:35:00Z"
    },
    "status_code": 200
  }
  ```

---

## 🔔 4. Notification Types

### 4.1. Notification Type Definitions

| Type | Trigger | Message | Data Fields |
|------|---------|---------|-------------|
| `post_created` | User creates a post | "New post from a user you follow" | `post_id`, `post_preview` |
| `post_reply` | User replies to a post | "Someone replied to your post" | `original_post_id`, `reply_id` |
| `follow_request` | User sends follow request | "Someone wants to follow you" | `follow_request_id` |
| `follow_accepted` | Follow request accepted | "Your follow request was accepted" | `follow_request_id` |

### 4.2. Notification Data Structure

```json
{
  "id": "unique_notification_id",
  "recipient_id": "user_receiving_notification", 
  "sender_id": "user_who_triggered_notification",
  "notification_type": "post_created|post_reply|follow_request|follow_accepted",
  "message": "Human readable message",
  "data": {
    // Type-specific data (see table above)
  },
  "is_read": false,
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z"
}
```

---

<!-- ## 🚀 5. Frontend Integration

### 5.1. Establishing SSE Connection

```javascript
// Connect to notifications stream
const notificationService = new EventSource(
  `/events/?channel=notifications-${userId}`,
  {
    headers: {
      'Authorization': `Bearer ${authToken}`
    }
  }
);

// Listen for new notifications
notificationService.addEventListener('notification', (event) => {
  const notification = JSON.parse(event.data);
  showNotification(notification);
  updateNotificationsList(notification);
});

// Listen for unread count updates
notificationService.addEventListener('unread_count_update', (event) => {
  const data = JSON.parse(event.data);
  updateUnreadCount(data.unread_count);
});
```

### 5.2. Fetching Notifications

```javascript
// Get all notifications
const response = await fetch('/api/v1/notifications/1/20/', {
  headers: {
    'Authorization': `Bearer ${authToken}`
  }
});

// Get only unread notifications
const unreadResponse = await fetch('/api/v1/notifications/1/20/?unread_only=true', {
  headers: {
    'Authorization': `Bearer ${authToken}`
  }
});
```

### 5.3. Marking Notifications as Read

```javascript
// Mark specific notifications as read
await fetch('/api/v1/notifications/mark-read/', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${authToken}`
  },
  body: JSON.stringify({
    notification_ids: ['notif1', 'notif2']
  })
});

// Mark all notifications as read
await fetch('/api/v1/notifications/mark-read/', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${authToken}`
  },
  body: JSON.stringify({})
});
``` -->

---

## 🔧 6. System Behavior

### 6.1. Real-time Delivery
- Notifications are sent instantly via SSE when created
- Users receive notifications immediately if online
- Multiple tabs/devices can receive notifications simultaneously

### 6.2. Offline Support  
- Unread notifications are stored in database
- When user comes online, they can fetch missed notifications
- Unread count is maintained and updated in real-time

### 6.3. Notification Preferences
- Users can disable specific types of notifications
- Disabled notifications are not created or sent
- Preferences are checked before notification creation
---

## 🚨 7. Error Handling

### 7.1. Common Error Responses

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

<!-- ### 7.2. SSE Error Handling

```javascript
notificationService.addEventListener('error', (event) => {
  console.log('SSE connection error, attempting to reconnect...');
  // Implement exponential backoff reconnection
});
``` -->

---