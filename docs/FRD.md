# Hapztext - Functional Requirements Document (FRD)

**Version:** 1.0  
**Date:** October 2025  
**Project:** Hapztext 

---

## Table of Contents
1. [Executive Summary](#1-executive-summary)
2. [System Architecture Overview](#2-system-architecture-overview)
3. [Architectural Layers & Components](#3-architectural-layers--components)
4. [Core Modules & Data Flow](#4-core-modules--data-flow)
5. [System Integration & Dependencies](#5-system-integration--dependencies)
6. [Security & Authentication Flow](#6-security--authentication-flow)
7. [Real-time Notification System](#7-real-time-notification-system)
8. [Database Schema & Relationships](#8-database-schema--relationships)
9. [API Endpoints & Request Flow](#9-api-endpoints--request-flow)
10. [Deployment Architecture](#10-deployment-architecture)

---

## 1. Executive Summary

### 1.1 Project Overview
Hapztext is a modern social media platform built using Django REST Framework, implementing a clean architecture pattern with clear separation of concerns. The application currently supports user authentication, social interactions (posts, reactions, follows), and real-time notifications.

### 1.2 Key Features
- **User Management**: Registration, authentication, profile management
- **Social Interactions**: Posts (text/media), reactions, comments, sharing, tagging/mentioning
- **Follow System**: Follow users, mutual friends, follower/following lists
- **Real-time Notifications**: Server-Sent Events (SSE) for instant notification updates
- **Content Management**: Scheduled posts, post tagging, multiple content types

### 1.3 Technology Stack
- **Backend Framework**: Django 5.* + Django REST Framework
- **Authentication**: Django REST Knox (Token-based)
- **Database**: PostgreSQL
- **Caching/Queue**: Redis
- **Server**: Daphne (ASGI)
- **Real-time**: django-eventstream (SSE)
- **Containerization**: Docker & Docker Compose

---

## 2. System Architecture Overview

### 2.1 Architectural Pattern
The application follows **Hexagonal Architecture (Ports & Adapters)** with clear layer separation:

```
┌─────────────────────────────────────────────────────────┐
│                  PRESENTATION LAYER                     │
│  (Views, Serializers, API Endpoints, URL Routing)       │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────────┐
│                  APPLICATION LAYER                      │
│           (Business Rules, DTOs, Ports)                 │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────────┐
│                   DOMAIN LAYER                          │
│    (Entities, Value Objects, Domain Logic, Enums)       │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────────┐
│                INFRASTRUCTURE LAYER                     │
│  (Repositories, Django Models, External Services)       │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Design Principles
1. **Dependency Inversion**: High-level modules don't depend on low-level modules
2. **Separation of Concerns**: Each layer has distinct responsibilities
3. **Testability**: Business logic isolated from frameworks
4. **Maintainability**: Easy to modify without affecting other layers

---

## 3. Architectural Layers & Components

### 3.1 Domain Layer (`apps/{app_name}/domain/`)
**Purpose**: Core business logic and rules independent of frameworks

**Components**:
- **Entities**: Core business objects (User, Post, Notification, etc.)
  - `users/entities.py`: User, UserProfile, UserFollowing
  - `posts/entities.py`: Post, PostReaction, PostShare, PostTag
  - `notifications/entities.py`: Notification, NotificationPreferences
  - `authentication/entities.py`: OTPCode

- **Value Objects**: Immutable objects representing domain concepts
  - `users/value_objects.py`: Ethnicity, RelationshipStatus, FollowRequestStatus
  - `posts/value_objects.py`: PostFormat, ReactionType
  - `notifications/value_objects.py`: NotificationType, NotificationData

- **Enums**: Defined constants for domain values
  - Consistent choices across the application

**Key Characteristics**:
- No dependencies on Django or external frameworks
- Pure Python dataclasses
- Domain validation logic included

---

### 3.2 Application Layer (`apps/{app_name}/application/`)
**Purpose**: Orchestrates business use cases and defines contracts

**Components**:

#### A. DTOs (Data Transfer Objects)
Located in `*/dtos.py` files:
- **Input DTOs**: Validate and structure incoming data
  - Example: `CreateUserDTO`, `PostDetailDTO`, `LoginDTO`
- **Output DTOs**: Format response data
  - Example: `UserResponseDTO`, `PostResponseDTO`, `NotificationResponseDTO`

#### B. Business Rules (Use Cases)
Located in `*/rules.py` files:
- **Authentication Rules**:
  - `RegisterRule`: User registration logic
  - `LoginRule`: Authentication logic
  - `EmailOTPRequestRule`: OTP generation and sending
  - `VerifyEmailRule`: Email verification
  - `ResetPasswordRule`: Password reset logic

- **User Rules**:
  - `FetchUserRule`: Retrieve user details
  - `CreateUserProfileRule`: Profile creation
  - `FollowUserRule`: Follow/unfollow logic
  - `SearchUserRule`: User search functionality

- **Post Rules**:
  - `CreatePostRule`: Post creation with validation
  - `PostListRule`: Fetch posts with pagination
  - `ReactToPostRule`: Handle post reactions
  - `SharePostRule`: Post sharing logic

- **Notification Rules**:
  - `CreateNotificationRule`: Notification creation
  - `NotifyFollowersOfPostRule`: Notify followers of new posts
  - `GetUserNotificationsRule`: Fetch user notifications

#### C. Ports
Located in `*/ports.py` files:
- Define contracts for external dependencies
- Examples:
  - `UserRepositoryInterface`
  - `PostRepositoryInterface`
  - `EmailServiceInterface`
  - `AuthenticationServiceInterface`
  - `NotificationServiceInterface`

---

### 3.3 Infrastructure Layer (`apps/{app_name}/infrastructure/`)
**Purpose**: Implements ports and interacts with external systems

**Components**:

#### A. Django Models (`*/models/tables.py`)
Database schema definitions:
- **User Models**: User, UserProfile, UserFollowing, UserMentionCount
- **Post Models**: Post, PostReaction, PostShare, PostTag
- **Notification Models**: Notification, NotificationPreferences
- **Authentication Models**: OTPCode

#### B. Repositories (`*/repositories.py`)
Implement repository interfaces:
- **Data Conversion Functions**:
  - `to_domain_*_data()`: Django model → Domain entity
  - `from_domain_*_data()`: Domain entity → Django model
- **CRUD Operations**: Create, Read, Update, Delete
- **Complex Queries**: Search, pagination, filtering

#### C. Services (`*/services.py`)
Adapt external services:
- **DjangoEmailServiceAdapter**: Email sending via Django
- **KnoxAuthenticationServiceAdapter**: Authentication token management
- **SSENotificationService**: Real-time notifications
- **NotificationDispatcher**: Notification routing

#### D. Supporting Files
- **Managers** (`users/managers.py`): Custom user manager
- **Channels** (`notifications/channels.py`): SSE channel management
- **Password Service** (`password_service.py`): Password hashing/validation

---

### 3.4 Presentation Layer (`apps/{app_name}/presentation/`)
**Purpose**: HTTP interface and API endpoints

**Components**:

#### A. Views (`views/*.py`)
Handle HTTP requests/responses:
- **Authentication Views**: Register, login, logout, password reset
- **User Views**: Profile CRUD, follow/unfollow, search
- **Post Views**: Create, list, react, share
- **Notification Views**: Fetch, mark read, preferences, SSE stream

**Request Processing Pattern**:
```python
1. Receive HTTP request
2. Validate with Serializer
3. Get Rule from Factory
4. Execute Rule with DTO
5. Format response
6. Return HTTP response
```

#### B. Serializers (`serializers/*.py`)
Request/response validation:
- Input validation with DRF serializers
- Convert request data to DTOs
- Custom validation logic
- Context handling for user-specific data

#### C. Factory (`factory.py`)
Dependency injection container:
- Creates and wires all dependencies
- Provides functions to get configured rules
- Manages repository and service instances
- Example:
```python
def get_register_rule() -> RegisterRule:
    return RegisterRule(
        user_repository=get_user_repository(),
        validate_password=validate_password,
        hash_password=hash_password,
    )
```

#### D. Response Handlers (`responses.py`)
Standardized response format:
- `StandardResponse.success()`: 200 OK
- `StandardResponse.created()`: 201 Created
- `StandardResponse.updated()`: 202 Accepted
- `StandardResponse.deleted()`: 204 No Content

---

## 4. Core Modules & Data Flow

### 4.1 Authentication Module

#### Registration Flow
```
Client Request
    ↓
POST /api/v1/authentication/register/
    ↓
CreateUserSerializer (validation)
    ↓
RegisterRule
    ├─> Validate password
    ├─> Hash password
    ├─> Create User entity
    └─> UserRepository.create()
        ↓
    Django User Model saved
        ↓
EmailOTPRequestRule (triggered)
    ├─> Generate OTP code
    ├─> OTPCodeRepository.create()
    └─> EmailService.send_otp_email()
        ↓
Response with user data
```

#### Login Flow
```
Client Request
    ↓
POST /api/v1/authentication/login/
    ↓
LoginSerializer (validation)
    ↓
LoginRule
    ├─> UserRepository.find_by_email()
    ├─> Check password (password_check)
    ├─> Verify email_verified status
    └─> AuthenticationService.generate_auth_tokens()
        ↓
Knox token created
        ↓
Response with tokens + user data
```

#### Password Reset Flow
```
Request Reset
    ↓
POST /api/v1/authentication/password-reset/request/
    ↓
EmailOTPRequestRule
    ├─> Find user
    ├─> Check if verified
    ├─> Generate OTP
    └─> Send email
        ↓
Confirm Reset
    ↓
POST /api/v1/authentication/password-reset/
    ↓
ResetPasswordRule
    ├─> Verify OTP
    ├─> Validate new password
    ├─> Hash password
    └─> Update user password
```

---

### 4.2 User Management Module

#### Profile Creation Flow
```
Client Request
    ↓
POST /api/v1/users/profile/create/
    ↓
UserProfileDetailSerializer (validation)
    ↓
CreateUserProfileRule
    ├─> Check profile doesn't exist
    ├─> Create UserProfile entity
    ├─> Validate value objects (Ethnicity, RelationshipStatus)
    └─> UserProfileRepository.create()
        ↓
Django UserProfile Model saved
        ↓
Response with profile data
```

#### Follow User Flow
```
Client Request
    ↓
POST /api/v1/users/follow-request/{user_id}/
    ↓
FollowRequestSerializer (validation)
    ↓
FollowUserRule
    ├─> Validate: not following self
    ├─> Check both users have profiles
    ├─> Create UserFollowing entity
    └─> UserFollowingRepository.create()
        ↓
Django UserFollowing Model saved
        ↓
NotifyUserOfFollowRule (triggered)
    └─> Create notification
        ↓
Response with follow data
```

#### Friends List Logic
**Friends = Mutual Followers**
```
GetFriendsListRule
    ↓
UserFollowingRepository.get_mutual_followers()
    ├─> Get users current user follows
    ├─> Get users who follow current user
    ├─> Find intersection (mutual)
    └─> Paginate results
        ↓
Response with friends profiles
```

---

### 4.3 Posts Module

#### Post Creation Flow
```
Client Request (with multipart/form-data)
    ↓
POST /api/v1/posts/
    ↓
PostCreateSerializer
    ├─> Validate post_format
    ├─> Validate content matches format
    ├─> Validate media files
    └─> Check scheduled_at if applicable
        ↓
CreatePostRule
    ├─> Create Post entity
    ├─> PostRepository.create()
    ├─> Create PostTags if tagged_user_ids
    └─> Increment mention counts
        ↓
Django Post Model saved
        ↓
IF is_reply:
    NotifyPostCreatorOfReplyRule
ELSE:
    NotifyFollowersOfPostRule
    ├─> Get all followers
    ├─> Check notification preferences
    └─> Create notifications for each
        ↓
Response with post data
```

#### Post Reaction Flow
```
Client Request
    ↓
POST /api/v1/posts/{post_id}/react/
    ↓
PostReactionSerializer (validation)
    ↓
ReactToPostRule
    ├─> Create PostReaction entity
    └─> PostReactionRepository.create_or_update()
        ↓
Django PostReaction Model saved/updated
        ↓
Response with reaction data
```

#### Fetch Posts List Flow
```
Client Request
    ↓
GET /api/v1/posts/list/{page}/{page_size}/
    ↓
PostListSerializer
    ├─> Validate pagination
    └─> Validate feed_type (timeline/trending/popular)
        ↓
PostListRule
    ├─> PostRepository.posts_list() OR
    │   PostRepository.trending_posts_list() OR
    │   PostRepository.popular_posts_list()
    ├─> Get post IDs
    ├─> PostReactionRepository.get_posts_reaction_counts()
    ├─> PostShareRepository.get_posts_share_counts()
    └─> Get current_user_reaction for each post
        ↓
Response with posts + pagination links
```

---

### 4.4 Notifications Module

#### Notification Creation Flow
```
Triggering Event (e.g., new post, follow)
    ↓
CreateNotificationRule
    ├─> Get recipient's preferences
    ├─> Check if notification type enabled
    ├─> Create Notification entity
    ├─> NotificationRepository.create()
    │   ↓
    │   Django Notification Model saved
    └─> NotificationDispatcher.dispatch_notification()
        ├─> Format notification data
        └─> SSENotificationService.send_real_time_notification()
            ├─> Get user channel (notifications-{user_id})
            └─> django_eventstream.send_event()
                ↓
            Real-time notification sent to connected clients
```

#### SSE Connection Flow
```
Client
    ↓
POST /api/v1/notifications/stream/
    ↓
notifications_stream_view
    ├─> Authenticate user
    ├─> Get user channel
    └─> django_eventstream.events(request)
        ↓
EventStream Connection Established
    ↓
AuthenticatedChannelManager.can_read_channel()
    ├─> Verify user owns channel
    └─> Allow/Deny access
        ↓
Client receives events:
    - notification: New notification
    - unread_count_update: Updated count
```

#### Fetch Notifications Flow
```
Client Request
    ↓
GET /api/v1/notifications/{page}/{page_size}/
    ↓
NotificationListSerializer
    ├─> Validate pagination
    └─> Validate unread_only flag
        ↓
GetUserNotificationsRule
    ├─> NotificationRepository.get_user_notifications()
    │   ├─> Filter by recipient_id
    │   ├─> Filter by is_read if unread_only
    │   └─> Paginate results
    └─> NotificationRepository.get_unread_count()
        ↓
Response with notifications + unread count
```

---

## 5. System Integration & Dependencies

### 5.1 Dependency Flow

```
┌─────────────────────────────────────────────────────────┐
│                    HTTP REQUEST                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│                 URL ROUTING (api/v1/)                   │
│  - authentication.py                                    │
│  - users.py                                             │
│  - posts.py                                             │
│  - notifications.py                                     │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│                 VIEW FUNCTION                           │
│  1. Authenticate request (Knox)                         │
│  2. Throttle check (Rate limiting)                      │
│  3. Parse request (JSON/MultiPart)                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│                 SERIALIZER                              │
│  - Validate input data                                  │
│  - Add context (user_id, etc.)                          │
│  - Convert to validated_data dict                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│                 FACTORY                                 │
│  - Get configured Rule instance                         │
│  - Inject dependencies (repositories, services)         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│            BUSINESS RULE (USE CASE)                     │
│  1. Convert validated_data to DTO                       │
│  2. Execute business logic                              │
│  3. Call repositories                                   │
│  4. Return response DTO                                 │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│                 REPOSITORY                              │
│  1. Convert domain entity to Django model               │
│  2. Perform database operations                         │
│  3. Convert Django model back to domain entity          │
│  4. Return entity                                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│                 DATABASE (PostgreSQL)                   │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│              RESPONSE BACK THROUGH LAYERS               │
│  Repository → Rule → View → StandardResponse            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│                    HTTP RESPONSE                        │
│  {                                                      │
│    "success": true,                                     │
│    "message": "...",                                    │
│    "data": {...},                                       │
│    "status_code": 200                                   │
│  }                                                      │
└─────────────────────────────────────────────────────────┘
```

### 5.2 Cross-Module Dependencies

#### Authentication → Users
- Registration creates User
- Email verification updates `User.is_email_verified`
- Login returns User data

#### Users → Posts
- Posts require authenticated User
- Posts reference sender (User)
- Post tags reference Users

#### Users → Notifications
- Follow requests create notifications
- Notifications have recipient and sender (Users)

#### Posts → Notifications
- New posts notify followers
- Post replies notify post creator
- Triggered via notification rules

#### Posts → Users (Follow System)
- Post visibility based on follow relationships
- Notifications sent to followers

---

## 6. Security & Authentication Flow

### 6.1 Knox Token Authentication

#### Token Generation
```python
# In KnoxAuthenticationServiceAdapter
1. User logs in successfully
2. Check token limit (default: 3 per user)
3. Delete oldest token if limit reached
4. Generate new token with AuthToken.objects.create()
5. Return token to client
```

#### Token Validation
```python
# For every authenticated request
1. Extract 'Authorization: Bearer <token>' header
2. Knox middleware validates token
3. Attach user to request.user
4. Proceed to view
```

#### Token Invalidation
```python
# On logout
1. Delete current token (request._auth.delete())
2. OR delete all tokens (batch logout)
3. Send user_logged_out signal
```

### 6.2 Permission Checks

**Endpoint Protection**:
- `@permission_classes([AllowAny])`: Public endpoints
- `@permission_classes([IsAuthenticated])`: Requires valid token

**Rate Limiting**:
- `@throttle_classes([AnonRateThrottle])`: 5 requests/min
- `@throttle_classes([UserRateThrottle])`: 10 requests/min

### 6.3 Data Access Control

**User-specific data**:
```python
# Example: Fetch user notifications
1. Extract user_id from request.user
2. Filter notifications by recipient_id == user_id
3. Only return data belonging to authenticated user
```

**SSE Channel Security**:
```python
# AuthenticatedChannelManager
1. Check if user is authenticated
2. Verify channel name matches user ID
3. notifications-{user_id} can only be read by that user
```

---

## 7. Real-time Notification System

### 7.1 Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    CLIENT (Browser)                      │
│  EventSource connection to /api/v1/notifications/stream/ │
└────────────────────┬─────────────────────────────────────┘
                     │ (SSE Connection)
                     ↓
┌──────────────────────────────────────────────────────────┐
│                 DAPHNE (ASGI Server)                     │
│              django-eventstream                          │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ↓
┌──────────────────────────────────────────────────────────┐
│                 REDIS (PubSub)                           │
│  Channel: notifications-{user_id}                        │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ↑
                     │ (Publish event)
┌──────────────────────────────────────────────────────────┐
│         NOTIFICATION DISPATCHER                          │
│  - Receives notification from CreateNotificationRule     │
│  - Formats notification data                             │
│  - Publishes to Redis channel                            │
└──────────────────────────────────────────────────────────┘
```

### 7.2 Event Types

**notification event**:
```json
{
  "id": "notif_123",
  "type": "post_created",
  "message": "New post from @username",
  "data": {"post_id": "post_456"},
  "sender_id": "user_789",
  "created_at": "2025-01-15T10:30:00Z",
  "is_read": false
}
```

**unread_count_update event**:
```json
{
  "unread_count": 5,
  "user_id": "user_123"
}
```

### 7.3 Connection Lifecycle

1. **Establish Connection**: Client opens EventSource to SSE endpoint
2. **Authentication**: Server validates Knox token
3. **Channel Assignment**: User assigned to `notifications-{user_id}` channel
4. **Keep-Alive**: Connection maintained with periodic heartbeats
5. **Event Streaming**: Server pushes events as they occur
6. **Auto-Reconnect**: Client reconnects on connection loss

---

## 8. Database Schema & Relationships

### 8.1 Core Tables

#### User Table
```sql
users_user
- id (PK, CharField)
- email (Unique, EmailField)
- username (Unique, CharField)
- password (CharField, hashed)
- is_email_verified (Boolean)
- is_active (Boolean)
- created_at (DateTime)
- updated_at (DateTime)
```

#### UserProfile Table
```sql
users_userprofile
- id (PK, CharField)
- user_id (FK → users_user, OneToOne)
- first_name (CharField)
- last_name (CharField)
- bio (TextField)
- birth_date (DateField)
- ethnicity (CharField, choices)
- relationship_status (CharField, choices)
- occupation (CharField)
- profile_picture (ImageField)
- location (CharField)
- height (DecimalField)
- weight (DecimalField)
- created_at (DateTime)
- updated_at (DateTime)
```

#### UserFollowing Table (Many-to-Many through)
```sql
users_userfollowing
- id (PK, CharField)
- follower_id (FK → users_userprofile)
- following_id (FK → users_userprofile)
- created_at (DateTime)
UNIQUE(follower_id, following_id)
```

#### Post Table
```sql
posts_post
- id (PK, CharField)
- sender_id (FK → users_user)
- post_format (CharField, choices: text/image/audio/video)
- text_content (TextField, nullable)
- image_content (ImageField, nullable)
- audio_content (FileField, nullable)
- video_content (FileField, nullable)
- is_reply (Boolean)
- previous_post_id (CharField, nullable)
- is_published (Boolean)
- scheduled_at (DateTime, nullable)
- created_at (DateTime)
- updated_at (DateTime)
```

#### PostReaction Table
```sql
posts_postreaction
- id (PK, CharField)
- user_id (FK → users_user)
- post_id (FK → posts_post)
- reaction (CharField)
- created_at (DateTime)
- updated_at (DateTime)
UNIQUE(user_id, post_id)
```

#### Notification Table
```sql
notifications_notification
- id (PK, CharField)
- recipient_id (FK → users_user)
- sender_id (FK → users_user)
- notification_type (CharField, choices)
- message (TextField)
- data (JSONField)
- is_read (Boolean)
- created_at (DateTime)
- updated_at (DateTime)
INDEX(recipient_id, is_read, created_at)
```

### 8.2 Relationships Diagram

```
users_user (1) <─────> (1) users__user_profile
    │                              │
    │                              │
    │(sender)              (follower/following)
    │                              │
    ↓                              ↓
posts_post                 users_userfollowing
    │                      (self-referential)
    │(post_id)
    │
    ├──> posts__post_reaction (Many)
    ├──> posts__post_share (Many)
    └──> posts__post_tag (Many) ─> users_user (tagged)

users_user (recipient/sender)
    │
    ↓
notifications_notification (Many)
```

---

## 9. API Endpoints & Request Flow

### 9.1 Authentication Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/authentication/register/` | Register new user |
| POST | `/api/v1/authentication/login/` | Login user |
| POST | `/api/v1/authentication/logout/` | Logout user |
| POST | `/api/v1/authentication/verify-email/request/` | Request email verification |
| POST | `/api/v1/authentication/verify-email/` | Confirm email verification |
| POST | `/api/v1/authentication/password-reset/request/` | Request password reset |
| POST | `/api/v1/authentication/password-reset/` | Confirm password reset |

### 9.2 User Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/users/` | Fetch current user |
| PUT | `/api/v1/users/update/` | Update user |
| POST | `/api/v1/users/profile/create/` | Create profile |
| GET | `/api/v1/users/profile/{user_id}/` | Fetch user profile |
| GET | `/api/v1/users/profiles/{page}/{page_size}/` | List profiles |
| POST | `/api/v1/users/follow-request/{user_id}/` | Follow user |
| GET | `/api/v1/users/friends/{page}/{page_size}/` | Get friends list |
| GET | `/api/v1/users/followers/{user_id}/{page}/{page_size}/` | Get followers |
| GET | `/api/v1/users/followings/{user_id}/{page}/{page_size}/` | Get followings |
| GET | `/api/v1/users/search/?query={q}` | Search users |
| GET | `/api/v1/users/friends/search/?query={q}` | Search friends |

### 9.3 Post Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/posts/` | Create post |
| GET | `/api/v1/posts/list/{page}/{page_size}/` | List posts |
| GET | `/api/v1/posts/user/{user_id}/{page}/{page_size}/` | User posts |
| POST | `/api/v1/posts/{post_id}/react/` | React to post |
| DELETE | `/api/v1/posts/{post_id}/react/delete/` | Remove reaction |
| POST | `/api/v1/posts/{post_id}/share/` | Share post |

### 9.4 Notification Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/notifications/{page}/{page_size}/` | Get notifications |
| POST | `/api/v1/notifications/mark-read/` | Mark as read |
| GET | `/api/v1/notifications/preferences/` | Get preferences |
| PUT | `/api/v1/notifications/preferences/update/` | Update preferences |
| POST | `/api/v1/notifications/stream/` | SSE connection |

---

## 10. Deployment Architecture

### 10.1 Docker Services

```yaml
services:
  db:           # PostgreSQL database
  redis:        # Redis for caching and SSE
  web:          # Django application (Daphne)
  mailhog:      # Email testing (development)
```

### 10.2 Service Communication

```
┌─────────────────────────────────────────────────────────┐
│                       NGINX                             │
│              (Reverse Proxy - Optional)                 │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ↓
┌─────────────────────────────────────────────────────────┐
│                   DAPHNE (ASGI)                         │
│           Django Application (Port 8000)                │
│  - HTTP/HTTPS requests                                  │
│  - WebSocket/SSE connections                            │
│  - API endpoints                                        │
└──────┬────────────────────┬─────────────────────┬───────┘
       │                    │                     │
       ↓                    ↓                     ↓
┌──────────────┐     ┌──────────────┐      ┌──────────────┐
│  PostgreSQL  │     │    Redis     │      │   MailHog    │
│   (Port      │     │  (Port 6379) │      │  (Port 1025) │
│    5432)     │     │              │      │              │
│              │     │ - SSE PubSub │      │ - Email      │
│ - User data  │     │ - Caching    │      │   testing    │
│ - Posts      │     │              │      │              │
│ - Notifs     │     │              │      │              │
└──────────────┘     └──────────────┘      └──────────────┘
```

### 10.3 Environment Configuration

**Development**:
- `DJANGO_ENVIRONMENT=development`
- Debug mode enabled
- Local database
- MailHog for emails

**Production**:
- `DJANGO_ENVIRONMENT=production`
- Debug mode disabled
- Production database
- Real email service (SMTP)
- Static files served via WhiteNoise

### 10.4 Startup Process

```bash
1. uv sync (Install dependencies)
2. python manage.py collectstatic --noinput
3. python manage.py migrate
4. daphne config.asgi:application -b 0.0.0.0 -p 8000
```

---

## Appendices

### A. Key Design Patterns

1. **Repository Pattern**: Data access abstraction
2. **Factory Pattern**: Dependency creation and injection
3. **DTO Pattern**: Data transfer between layers
4. **Ports & Adapters**: Hexagonal architecture
5. **Observer Pattern**: Notification system

### B. Error Handling Strategy

- **Validation Errors**: Caught by serializers → 400 Bad Request
- **Business Rule Violations**: Raised by Rules → 400 Bad Request
- **Authentication Errors**: Handled by Knox → 401 Unauthorized
- **Database Errors**: Caught by repositories → 409 Conflict or 500 Internal Server Error
- **Unhandled Exceptions**: Custom exception handler → Standardized error response

### C. Performance Considerations

- **Database Indexes**: Added on frequently queried fields
- **Pagination**: Implemented on all list endpoints
- **Select/Prefetch Related**: Used to reduce database queries
- **Connection Pooling**: Django database connection pooling
- **Static Files**: Served via WhiteNoise with compression


---

**Document Version History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | October 2025 | System | Initial FRD creation |

---

**End of Functional Requirements Document**