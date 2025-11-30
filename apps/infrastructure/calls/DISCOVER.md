### Client-Side Guide: Discover WebSocket Interaction

This guide details the communication protocol and message structures required for the client (frontend) to interact with the Django Channels-based Discover WebSocket (`/ws/discover/`).

---

## 1\. Connection and Authentication

The WebSocket connection must be established securely and requires user authentication using a **Knox token**.

### Connection Endpoint

| Parameter          | Value                                       |
| :----------------- | :------------------------------------------ |
| **Protocol**       | `ws` (HTTP) or `wss` (HTTPS)                |
| **Endpoint**       | `/ws/discover/`                             |
| **Authentication** | Knox Token (must be sent during connection) |

### Authentication Methods

The `TokenAuthMiddleware` supports two ways to send your token:

1.  **Query Parameter (Recommended for initial connection):**
    ```
    ws://your.backend.domain/ws/discover/?token=<Your_Knox_Token>
    ```
2.  **WebSocket Headers:**
    - Header: `Authorization`
    - Value: `Bearer <Your_Knox_Token>`

### Initial Server Response

Upon successful connection, the server will send a confirmation message, followed immediately by the first chunk of the active user list.

| Field             | Description                                                     |
| :---------------- | :-------------------------------------------------------------- |
| **`type`**        | `"connection_success"`                                          |
| **`message`**     | `"connection successful"`                                       |
| **`data.events`** | Lists valid event types for client-to-send and backend-to-send. |

---

## 2\. Client-to-Server Events (Actions)

To perform an action or request data, the client sends a JSON object with a specific `"type"` field.

### A. Requesting the Active User List (`get_list`)

Use this event to fetch the initial list or subsequent pages of active users.

| Field                 | Type      | Description                                                                                                   |
| :-------------------- | :-------- | :------------------------------------------------------------------------------------------------------------ |
| **`type`**            | `string`  | **`"get_list"`**                                                                                              |
| **`previous_cursor`** | `integer` | The cursor value received from the previous `discover_list` response. **Use `0` for the very first request.** |

**Example Request (Initial Load):**

```json
{
	"type": "get_list",
	"previous_cursor": 0
}
```

### B. Leaving Discover Mode (`leave_discover`)

Use this event for exit, notifying the backend to remove your presence and broadcast a "user left" message. The connection will be closed afterward.

| Field      | Type     | Description            |
| :--------- | :------- | :--------------------- |
| **`type`** | `string` | **`"leave_discover"`** |

**Example Request:**

```json
{
	"type": "leave_discover"
}
```

---

## 3\. 🖥️ Server-to-Client Events (Data)

These are the messages the client must be prepared to handle to manage the state of active users.

### A. Active User List Response (`discover_list`)

Sent in response to `get_list` and immediately after connection. This message contains a chunk of active users and the cursor needed for the next page.

| Field                 | Type           | Description                                                                                                                                     |
| :-------------------- | :------------- | :---------------------------------------------------------------------------------------------------------------------------------------------- |
| **`type`**            | `string`       | **`"discover_list"`**                                                                                                                           |
| **`data`**            | `list[object]` | The array of user objects currently active.                                                                                                     |
| **`limit`**           | `integer`      | The maximum number of users requested (e.g., `100`).                                                                                            |
| **`previous_cursor`** | `integer`      | **The value to send in the next `get_list` request.** If this value is `0` and you've processed the list, the end of the list has been reached. |

**Example Response:**

```json
{
	"type": "discover_list",
	"data": [
		{
			"user_id": "1233we3we3we3we3we3we",
			"username": "Alice",
			"joined_at": "1732948800.0"
		},
		{
			"user_id": "456desdesdesdesdesdes",
			"username": "Bob",
			"joined_at": "1732948805.0"
		}
	],
	"limit": 100,
	"previous_cursor": 84521 // Send this value in the next "get_list" request
}
```

### B. Real-Time Presence Updates (`discover_presence`)

Broadcast to all users in the group when someone joins or leaves.

| Field          | Type     | Description                                |
| :------------- | :------- | :----------------------------------------- |
| **`type`**     | `string` | **`"discover_presence"`**                  |
| **`event`**    | `string` | `"user_joined"` or `"user_left"`.          |
| **`user_id`**  | `string` | The ID of the user whose presence changed. |
| **`username`** | `string` | The username of the user.                  |

**Example Response (User Joined):**

```json
{
	"type": "discover_presence",
	"event": "user_joined",
	"user_id": "789desdesdesdesdesde",
	"username": "Charlie"
}
```

### C. Full List Updates (`discover_list_update`)

Sent to all users when a user joins or leaves to provide an updated chunk of the active list.

| Field      | Type           | Description                                       |
| :--------- | :------------- | :------------------------------------------------ |
| **`type`** | `string`       | **`"discover_list_update"`**                      |
| **`data`** | `list[object]` | The updated list of users (e.g., the first page). |

**Note:** The consumer logic currently **filters out the newly joined user** before sending this update list to the group. The client should use the data in this message to refresh its local list.

### D. Error Messages (`error`)

Sent if the client sends an invalid request (e.g., non-integer cursor) or if a backend error occurs.

| Field             | Type      | Description                                                                            |
| :---------------- | :-------- | :------------------------------------------------------------------------------------- |
| **`type`**        | `string`  | **`"error"`**                                                                          |
| **`message`**     | `string`  | A human-readable description of the error.                                             |
| **`status_code`** | `integer` | A specific error code (e.g., `4000` for client-side errors, `5000` for server errors). |

---

## 4\. Handling User Data

The core user object contained within the `data` array of `discover_list` messages has the following guaranteed fields:

- `user_id` (string)
- `username` (string)
- `joined_at` (string - UNIX timestamp)

Any `additional_data` provided during `enter_discover` will also be present in this object.
