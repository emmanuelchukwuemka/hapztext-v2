# 🔗 API Guide for Frontend Developers 🚀

This document provides a detailed guide to the backend API endpoints, designed for frontend developers. It includes information on authentication, user management, and post-related operations. Each section describes the endpoint URL, HTTP method, a brief description, authentication requirements, request body structure, and example success/error responses.

## 🌐 Base URL

All API endpoints are prefixed with `/api/v1/`.

---

## 🔐 1. Authentication Endpoints

### 1.1. 📝 Register User

-   **🔗 Endpoint:** `/api/v1/authentication/register/`
-   **📡 HTTP Method:** `POST`
-   **📝 Description:** Registers a new user and sends an OTP code to their email for verification.
-   **🔐 Authentication:** None (Public)
-   **📤 Request Body:**
    ```json
    {
        "email": "string", (required)
        "username": "string", (required)
        "password": "string", (required)
        "password_confirm": "string" (required)
    }
    ```
    **🔒 Password Validation:**
    -   Must not contain spaces.
    -   Must contain at least one lowercase character.
    -   Must contain at least one uppercase character.
    -   Must contain at least one special character (~!@#$%^&*()-=+:;,./<>?).
-   **✅ Success Response (Status: 201 Created):**
    ```json
    {
        "success": true,
        "message": "Registration successful. An OTP code has been sent to your email for verification.",
        "data": {
            "id": "string",
            "email": "string",
            "username": "string",
            "is_email_verified": false,
            "created_at": "datetime",
            "updated_at": "datetime"
        },
        "status_code": 201
    }
    ```

### 1.2. 🔄 Request Email Verification

-   **🔗 Endpoint:** `/api/v1/authentication/verify-email/request/`
-   **📡 HTTP Method:** `POST`
-   **📝 Description:** Requests an email verification OTP code for an unverified user.
-   **🔐 Authentication:** None (Public)
-   **📤 Request Body:**
    ```json
    {
        "email": "string" (required)
    }
    ```
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "Email verification OTP code sent successfully.",
        "data": {},
        "status_code": 200
    }
    ```

### 1.3. ✅ Verify Email

-   **🔗 Endpoint:** `/api/v1/authentication/verify-email/`
-   **📡 HTTP Method:** `POST`
-   **📝 Description:** Verifies a new user's email using an OTP code.
-   **🔐 Authentication:** None (Public)
-   **📤 Request Body:**
    ```json
    {
        "email": "string", (required)
        "otp_code": "string" (required)
    }
    ```
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "Email verification successful.",
        "data": {},
        "status_code": 200
    }
    ```

### 1.4. 🔑 Login User

-   **🔗 Endpoint:** `/api/v1/authentication/login/`
-   **📡 HTTP Method:** `POST`
-   **📝 Description:** Logs in a verified user and returns an authentication token.
-   **🔐 Authentication:** None (Public)
-   **📤 Request Body:**
    ```json
    {
        "email": "string", (required)
        "password": "string" (required)
    }
    ```
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "Login successful.",
        "data": {
            "id": "string",
            "email": "string",
            "username": "string",
            "tokens": {
                "auth": "string"
            }
        },
        "status_code": 200
    }
    ```

### 1.5. 🚪 Logout User

-   **🔗 Endpoint:** `/api/v1/authentication/logout/`
-   **📡 HTTP Method:** `POST`
-   **📝 Description:** Logs out an authenticated user by invalidating their token.
-   **🔐 Authentication:** Required (Bearer Token in Header: `Authorization: Bearer <auth_token>`)
-   **📤 Request Body:**
    ```json
    {
        "auth_token": "string" (required)
    }
    ```
-   **✅ Success Response (Status: 204 No Content):**
    ```json
    {
        "success": true,
        "message": "Logout successful.",
        "data": {},
        "status_code": 204
    }
    ```

### 1.6. 🔄 Request Password Reset

-   **🔗 Endpoint:** `/api/v1/authentication/password-reset/request/`
-   **📡 HTTP Method:** `POST`
-   **📝 Description:** Requests a password reset for a verified user, sending an OTP to their email.
-   **🔐 Authentication:** None (Public)
-   **📤 Request Body:**
    ```json
    {
        "email": "string" (required)
    }
    ```
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "Password reset OTP code sent successfully.",
        "data": {},
        "status_code": 200
    }
    ```

### 1.7. 🔐 Confirm Password Reset

-   **🔗 Endpoint:** `/api/v1/authentication/password-reset/`
-   **📡 HTTP Method:** `POST`
-   **📝 Description:** Confirms the password reset using the OTP code and sets a new password.
-   **🔐 Authentication:** None (Public)
-   **📤 Request Body:**
    ```json
    {
        "new_password": "string", (required)
        "new_password_confirm": "string", (required)
        "otp_code": "string" (required)
    }
    ```
    **🔒 New Password Validation:**
    -   Must not contain spaces.
    -   Must contain at least one lowercase character.
    -   Must contain at least one uppercase character.
    -   Must contain at least one special character (~!@#$%^&*()-=+:;,./<>?).
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "Password reset successful.",
        "data": {},
        "status_code": 200
    }
    ```

---

## 👥 2. User Endpoints

### 2.1. 👤 Fetch User

-   **🔗 Endpoint:** `/api/v1/users/`
-   **📡 HTTP Method:** `GET`
-   **📝 Description:** Fetches details of the authenticated user.
-   **🔐 Authentication:** Required (Bearer Token in Header: `Authorization: Bearer <auth_token>`)
-   **📤 Request Body:** None
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "User fetched successfully.",
        "data": {
            "id": "string",
            "username": "string"
        },
        "status_code": 200
    }
    ```

### 2.2. ✏️ Update User

-   **🔗 Endpoint:** `/api/v1/users/update/`
-   **📡 HTTP Method:** `PUT`
-   **📝 Description:** Updates details of the authenticated user.
-   **🔐 Authentication:** Required (Bearer Token in Header: `Authorization: Bearer <auth_token>`)
-   **📤 Request Body:**
    ```json
    {
        "username": "string" (optional)
    }
    ```
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "User update successful.",
        "data": {
            "id": "string",
            "username": "string"
        },
        "status_code": 200
    }
    ```

### 2.3. 👤 Create User Profile

-   **🔗 Endpoint:** `/api/v1/users/profile/create/`
-   **📡 HTTP Method:** `POST`
-   **📝 Description:** Creates a profile for the authenticated user.
-   **🔐 Authentication:** Required (Bearer Token in Header: `Authorization: Bearer <auth_token>`)
-   **📤 Request Body:** (Can be `application/json` or `multipart/form-data` for `profile_picture`)
    ```json
    {
        "birth_date": "YYYY-MM-DD", (optional)
        "ethnicity": "string", (optional, choices: "AFRICAN_AMERICAN", "ASIAN", "CAUCASIAN", "HISPANIC", "NATIVE_AMERICAN", "OTHER")
        "relationship_status": "string", (optional, choices: "SINGLE", "IN_A_RELATIONSHIP", "MARRIED", "DIVORCED", "WIDOWED")
        "first_name": "string", (optional)
        "last_name": "string", (optional)
        "bio": "string", (optional)
        "occupation": "string", (optional)
        "profile_picture": "file", (optional)
        "height": "decimal", (optional, max_digits=5, decimal_places=2)
        "weight": "decimal" (optional, max_digits=5, decimal_places=2)
    }
    ```
-   **✅ Success Response (Status: 201 Created):**
    ```json
    {
        "success": true,
        "message": "User profile creation successful.",
        "data": {
            "user_id": "string",
            "birth_date": "YYYY-MM-DD",
            "ethnicity": "string",
            "relationship_status": "string",
            "first_name": "string",
            "last_name": "string",
            "bio": "string",
            "occupation": "string",
            "profile_picture": "url_to_image",
            "height": "decimal",
            "weight": "decimal",
            "id": "string",
            "created_at": "datetime",
            "updated_at": "datetime"
        },
        "status_code": 201
    }
    ```

### 2.4. 👀 Fetch User Profile

-   **🔗 Endpoint:** `/api/v1/users/profile/<str:user_id>/`
-   **📡 HTTP Method:** `GET`
-   **📝 Description:** Fetches the profile details of a specific user.
-   **🔐 Authentication:** Required (Bearer Token in Header: `Authorization: Bearer <auth_token>`)
-   **🔗 URL Parameters:**
    -   `user_id`: string (required) - The ID of the user whose profile is to be fetched.
-   **📤 Request Body:** None
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "User profile fetched successfully.",
        "data": {
            "user_id": "string",
            "birth_date": "YYYY-MM-DD",
            "ethnicity": "string",
            "relationship_status": "string",
            "first_name": "string",
            "last_name": "string",
            "bio": "string",
            "occupation": "string",
            "profile_picture": "url_to_image",
            "height": "decimal",
            "weight": "decimal",
            "id": "string",
            "created_at": "datetime",
            "updated_at": "datetime"
        },
        "status_code": 200
    }
    ```

### 2.5. 📋 Fetch User Profiles List

-   **🔗 Endpoint:** `/api/v1/users/profiles/<int:page>/<int:page_size>/`
-   **📡 HTTP Method:** `GET`
-   **📝 Description:** Fetches a paginated list of all user profiles.
-   **🔐 Authentication:** Required (Bearer Token in Header: `Authorization: Bearer <auth_token>`)
-   **🔗 URL Parameters:**
    -   `page`: integer (required) - The page number for pagination.
    -   `page_size`: integer (required) - The number of profiles per page.
-   **📤 Request Body:** None
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "User profiles fetched successfully.",
        "data": {
            "result": [
                {
                    "user_id": "string",
                    "birth_date": "YYYY-MM-DD",
                    "ethnicity": "string",
                    "relationship_status": "string",
                    "first_name": "string",
                    "last_name": "string",
                    "bio": "string",
                    "occupation": "string",
                    "profile_picture": "url_to_image",
                    "height": "decimal",
                    "weight": "decimal",
                    "id": "string",
                    "created_at": "datetime",
                    "updated_at": "datetime"
                }
            ],
            "previous_profiles_data": "string",
            "next_profiles_data": "string"
        },
        "status_code": 200
    }
    ```

### 2.6. 📤 Send Follow Request

-   **🔗 Endpoint:** `/api/v1/users/follow-request/<str:user_id>/`
-   **📡 HTTP Method:** `POST`
-   **📝 Description:** Sends a follow request to another user.
-   **🔐 Authentication:** Required (Bearer Token in Header: Authorization: Bearer <auth_token>)
-   **🔗 URL Parameters:**
    - `user_id`: string (required) - The ID of the user to send a follow request to.
-   **📤 Request Body:** None
-   **✅ Success Response (Status: 201 Created):**
    ```json
    {
        "success": true,
        "message": "Follow request sent successfully.",
        "data": {
            "id": "string",
            "requester_id": "string",
            "target_user_id": "string",
            "status": "pending",
            "created_at": "datetime",
            "updated_at": "datetime"
        },
        "status_code": 201
    }
    ```

### 2.7. ✅❌ Handle Follow Request

-   **🔗 Endpoint:** `/api/v1/users/follow-request/handle/<str:request_id>/`
-   **📡 HTTP Method:** `POST`
-   **📝 Description:** Accept or decline a follow request.
-   **🔐 Authentication:** Required (Bearer Token in Header: Authorization: Bearer <auth_token>)
-   **🔗 URL Parameters:**
    - `request_id`: string (required) - The ID of the follow request to handle.
-   **📤 Request Body:**
    ```json
    {
        "action": "accept" // or "decline"
    }
    ```
-   **✅ Success Response (Status: 201 Created):**
    ```json
    {
        "success": true,
        "message": "Follow request accepted successfully.",
        "data": {
            "id": "string",
            "requester_id": "string",
            "target_user_id": "string",
            "status": "accepted", // or "declined"
            "created_at": "datetime",
            "updated_at": "datetime"
        },
        "status_code": 200
    }
    ```

### 2.8. 📋 Get Pending Requests (Paginated)

-   **🔗 Endpoint:** `/api/v1/users/follow-requests/pending/<int:page>/<int:page_size>/`
-   **📡 HTTP Method:** `GET`
-   **📝 Description:** Get pending follow requests (both sent and received) with pagination.
-   **🔐 Authentication:** Required (Bearer Token in Header: Authorization: Bearer <auth_token>)
-   **🔗 URL Parameters:**
    - `page`: integer (required) - The page number (starts from 1).
    - `page_size`: integer (required) - Number of requests per page (1-100).
-   **📤 Request Body:** None
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "Pending requests fetched successfully.",
        "data": {
            "received_requests": [
                {
                    "id": "string",
                    "requester_id": "string",
                    "target_user_id": "string",
                    "status": "pending",
                    "created_at": "datetime",
                    "updated_at": "datetime"
                }
            ],
            "sent_requests": [
                {
                    "id": "string",
                    "requester_id": "string",
                    "target_user_id": "string", 
                    "status": "pending",
                    "created_at": "datetime",
                    "updated_at": "datetime"
                }
            ],
            "previous_requests_data": "/api/v1/users/follow-requests/pending/1/10/",
            "next_requests_data": "/api/v1/users/follow-requests/pending/3/10/",
        },
        "status_code": 200
    }
    ```
### 2.9. 👫 Get Friends List (Paginated)

-   **🔗 Endpoint:** `/api/v1/users/friends/<int:page>/<int:page_size>/`
-   **📡 HTTP Method:** `GET`
-   **📝 Description:** Get list of friends (users who mutually follow each other) with pagination.
-   **🔐 Authentication:** Required (Bearer Token in Header: Authorization: Bearer <auth_token>)
-   **🔗 URL Parameters:**
    - `page`: integer (required) - The page number (starts from 1).
    - `page_size`: integer (required) - Number of friends per page (1-100).
-   **📤 Request Body:** None
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "Friends list fetched successfully.",
        "data": {
            "friends": [
                {
                    "user_id": "string",
                    "birth_date": "YYYY-MM-DD",
                    "ethnicity": "string", 
                    "relationship_status": "string",
                    "first_name": "string",
                    "last_name": "string",
                    "bio": "string",
                    "occupation": "string",
                    "profile_picture": "url_to_image",
                    "height": "decimal",
                    "weight": "decimal",
                    "id": "string",
                    "created_at": "datetime",
                    "updated_at": "datetime"
                }
            ],
            "previous_friends_link": "/api/v1/users/friends/1/10/",
            "next_friends_link": "/api/v1/users/friends/3/10/"
        },
        "status_code": 200
    }
    ```

### 2.10. 👥 Get User Followers (Paginated)

-   **🔗 Endpoint:** `/api/v1/users/followers/<str:user_id>/<int:page>/<int:page_size>/`
-   **📡 HTTP Method:** `GET`
-   **📝 Description:** Get list of followers for a specific user with pagination.
-   **🔐 Authentication:** Required (Bearer Token in Header: Authorization: Bearer <auth_token>)
-   **🔗 URL Parameters:**
    - `user_id`: string (required) - The ID of the user whose followers to fetch.
    - `page`: integer (required) - The page number (starts from 1).
    - `page_size`: integer (required) - Number of followers per page (1-100).
-   **📤 Request Body:** None
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "User followers fetched successfully.",
        "data": {
            "followers": [
                {
                    "user_id": "string",
                    "birth_date": "YYYY-MM-DD",
                    "ethnicity": "string", 
                    "relationship_status": "string",
                    "first_name": "string",
                    "last_name": "string",
                    "bio": "string",
                    "occupation": "string",
                    "profile_picture": "url_to_image",
                    "location": "string",
                    "height": "decimal",
                    "weight": "decimal",
                    "id": "string",
                    "created_at": "datetime",
                    "updated_at": "datetime"
                }
            ],
            "previous_followers_data": "/api/v1/users/followers/user123/1/10/",
            "next_followers_data": "/api/v1/users/followers/user123/3/10/"
        },
        "status_code": 200
    }
    ```

### 2.11. 👤 Get User Followings (Paginated)

-   **🔗 Endpoint:** `/api/v1/users/followings/<str:user_id>/<int:page>/<int:page_size>/`
-   **📡 HTTP Method:** `GET`
-   **📝 Description:** Get list of users that a specific user follows with pagination.
-   **🔐 Authentication:** Required (Bearer Token in Header: Authorization: Bearer <auth_token>)
-   **🔗 URL Parameters:**
    - `user_id`: string (required) - The ID of the user whose followings to fetch.
    - `page`: integer (required) - The page number (starts from 1).
    - `page_size`: integer (required) - Number of followings per page (1-100).
-   **📤 Request Body:** None
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "User followings fetched successfully.",
        "data": {
            "followings": [
                {
                    "user_id": "string",
                    "birth_date": "YYYY-MM-DD",
                    "ethnicity": "string", 
                    "relationship_status": "string",
                    "first_name": "string",
                    "last_name": "string",
                    "bio": "string",
                    "occupation": "string",
                    "profile_picture": "url_to_image",
                    "location": "string",
                    "height": "decimal",
                    "weight": "decimal",
                    "id": "string",
                    "created_at": "datetime",
                    "updated_at": "datetime"
                }
            ],
            "previous_followings_data": "/api/v1/users/followings/user123/1/10/",
            "next_followings_data": "/api/v1/users/followings/user123/3/10/"
        },
        "status_code": 200
    }
    ```

---

## 📝 3. Post Endpoints

### 3.1. ✨ Create Post

-   **🔗 Endpoint:** `/api/v1/posts/`
-   **📡 HTTP Method:** `POST`
-   **📝 Description:** Creates a new post for the authenticated user.
-   **🔐 Authentication:** Required (Bearer Token in Header: `Authorization: Bearer <auth_token>`)
-   **📤 Request Body:** (Can be `application/json` or `multipart/form-data` for `media`)
    ```json
    {
        "post_format": "text",
        "text_content": "string", (optional for media uploads)
        "text_content": "file" (optional)
        "image_content": "file" (optional)
        "audio_content": "file" (optional)
        "video_content": "file" (optional)
    }
    ```
-   **✅ Success Response (Status: 201 Created):**
    ```json
    {
        "success": true,
        "message": "Post created successfully.",
        "data": {
            "id": "string",
            "sender": "string",
            "post_format": "",
            "text_content": "string",
            "image_content": null,
            "audio_content": null,
            "video_content": null,
            "is_reply": false,
            "previous_post_id": null,
            "sender_username": "string",
            "created_at": "datetime",
            "updated_at": "datetime"
        },
        "status_code": 201
    }
    ```
-   **❌ Error Response (Status: 400 Bad Request / 500 Internal Server Error):**
    ```json
    {
        "success": false,
        "message": "Error description",
        "errors": {
            "field_name": ["Error message"]
        },
        "status_code": 400
    }
    ```

### 3.2. 📋 Fetch Posts List

-   **🔗 Endpoint:** `/api/v1/posts/list/<int:page>/<int:page_size>/`
-   **📡 HTTP Method:** `GET`
-   **📝 Description:** Fetches a paginated list of all posts.
-   **🔐 Authentication:** Required (Bearer Token in Header: `Authorization: Bearer <auth_token>`)
-   **🔗 URL Parameters:**
    -   `page`: integer (required) - The page number for pagination.
    -   `page_size`: integer (required) - The number of posts per page.
-   **📤 Request Body:** None
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "Posts fetched successfully.",
        "data": {
            "result": [
                {
                    "id": "string",
                    "sender": "string",
                    "post_format": "",
                    "text_content": "string",
                    "image_content": null,
                    "audio_content": null,
                    "video_content": null,
                    "is_reply": false,
                    "previous_post_id": null,
                    "sender_username": "string",
                    "created_at": "datetime",
                    "updated_at": "datetime"
                }
            ],
            "previous_posts_data": "string",
            "next_posts_data": "string"
        },
        "status_code": 200
    }
    ```
-   **❌ Error Response (Status: 400 Bad Request / 500 Internal Server Error):**
    ```json
    {
        "success": false,
        "message": "Error description",
        "errors": {
            "field_name": ["Error message"]
        },
        "status_code": 400
    }
    ```

### 3.3. 👤 Fetch User Posts (Paginated)

-   **🔗 Endpoint:** `/api/v1/posts/user/<str:user_id>/<int:page>/<int:page_size>/`
-   **📡 HTTP Method:** `GET`
-   **📝 Description:** Fetches a paginated list of posts for a specific user.
-   **🔐 Authentication:** Required (Bearer Token in Header: `Authorization: Bearer <auth_token>`)
-   **🔗 URL Parameters:**
    -   `user_id`: string (required) - The ID of the user whose posts to fetch.
    -   `page`: integer (required) - The page number for pagination.
    -   `page_size`: integer (required) - The number of posts per page.
-   **📤 Request Body:** None
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "User posts fetched successfully.",
        "data": {
            "result": [
                {
                    "id": "string",
                    "sender": "string",
                    "post_format": "",
                    "text_content": "string",
                    "image_content": null,
                    "audio_content": null,
                    "video_content": null,
                    "is_reply": false,
                    "previous_post_id": null,
                    "sender_username": "string",
                    "created_at": "datetime",
                    "updated_at": "datetime"
                }
            ],
            "previous_posts_data": "/api/v1/posts/user/user123/1/10/",
            "next_posts_data": "/api/v1/posts/user/user123/3/10/"
        },
        "status_code": 200
    }
    ```
-   **❌ Error Response (Status: 400 Bad Request / 500 Internal Server Error):**
    ```json
    {
        "success": false,
        "message": "Error description",
        "errors": {
            "field_name": ["Error message"]
        },
        "status_code": 400
    }
    ```

---

## 📚 4. API Documentation

### 4.1. 📖 Swagger UI Documentation

-   **🔗 URL:** `/api/docs/swagger-ui/`
-   **📝 Description:** Interactive API documentation with Swagger UI interface.

### 4.2. 📖 ReDoc Documentation

-   **🔗 URL:** `/api/docs/redoc/`
-   **📝 Description:** Alternative API documentation with ReDoc interface.

### 4.3. 📖 OpenAPI Schema

-   **🔗 URL:** `/api/schema/`
-   **📝 Description:** Raw OpenAPI schema in JSON format.

---

## 🔧 5. Authentication

### 5.1. 🔑 Bearer Token Authentication

For protected endpoints, include the authentication token in the request header:

```
Authorization: Bearer <your_auth_token>
```

### 5.2. 📝 Rate Limiting

-   **Anonymous Users:** Limited requests per minute for public endpoints
-   **Authenticated Users:** Higher rate limits for protected endpoints

---

## 📋 6. Common Response Format

All API responses follow a consistent format:

### ✅ Success Response
```json
{
    "success": true,
    "message": "Operation successful message",
    "data": {
        // Response data
    },
    "status_code": 200
}
```

### ❌ Error Response
```json
{
    "success": false,
    "message": "Error description",
    "errors": {
        "field_name": ["Error message"]
    },
    "status_code": 400
}
```

## 👫 7. Friends Logic
-   **What Makes Users "Friends"?**
Users are considered friends when both conditions are met:
1) `User A` → `User B`: Has an accepted follow request
2) `User B` → `User A`: Has an accepted follow request