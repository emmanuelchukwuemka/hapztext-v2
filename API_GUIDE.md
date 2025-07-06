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
            "is_verified": false
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
            "field_name(or 'detail')": ["Error message"]
        },
        "status_code": 400
    }
    ```

### 1.2. ✅ Verify Email

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

### 1.3. 🔑 Login User

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
            "user_id": "string",
            "email": "string",
            "username": "string",
            "auth_token": "string"
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

### 1.4. 🚪 Logout User

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

### 1.5. 🔄 Request Password Reset

-   **🔗 Endpoint:** `/api/v1/authentication/password-reset/`
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

### 1.6. 🔐 Confirm Password Reset

-   **🔗 Endpoint:** `/api/v1/authentication/password-reset/confirm/`
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
            "username": "string",
            "email": "string",
            "is_verified": true
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

### 2.2. ✏️ Update User

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
            "username": "string",
            "email": "string",
            "is_verified": true
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
            "weight": "decimal"
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
            "weight": "decimal"
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
            "profiles": [
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
                    "weight": "decimal"
                }
            ],
            "total_pages": "integer",
            "current_page": "integer",
            "page_size": "integer",
            "total_count": "integer"
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

### 2.6. 👥 Follow User

-   **🔗 Endpoint:** `/api/v1/users/follow/<str:user_id>/`
-   **📡 HTTP Method:** `POST`
-   **📝 Description:** Allows an authenticated user to follow another user.
-   **🔐 Authentication:** Required (Bearer Token in Header: `Authorization: Bearer <auth_token>`)
-   **🔗 URL Parameters:**
    -   `user_id`: string (required) - The ID of the user to be followed.
-   **📤 Request Body:** None
-   **✅ Success Response (Status: 200 OK):**
    ```json
    {
        "success": true,
        "message": "User followed successfully.",
        "data": {
            "follower_id": "string",
            "following_id": "string"
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

## 📝 3. Post Endpoints

### 3.1. ✨ Create Post

-   **🔗 Endpoint:** `/api/v1/posts/`
-   **📡 HTTP Method:** `POST`
-   **📝 Description:** Creates a new post for the authenticated user.
-   **🔐 Authentication:** Required (Bearer Token in Header: `Authorization: Bearer <auth_token>`)
-   **📤 Request Body:** (Can be `application/json` or `multipart/form-data` for `media`)
    ```json
    {
        "caption": "string", (optional)
        "media": "file" (optional)
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
            "caption": "string",
            "media": "url_to_media",
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
            "posts": [
                {
                    "id": "string",
                    "sender": "string",
                    "caption": "string",
                    "media": "url_to_media",
                    "created_at": "datetime",
                    "updated_at": "datetime"
                }
            ],
            "total_pages": "integer",
            "current_page": "integer",
            "page_size": "integer",
            "total_count": "integer"
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
