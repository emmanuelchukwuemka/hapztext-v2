### Client-Side WebSocket Interaction Guide

The `WebRTCConsumer` is the **signaling server** that coordinates real-time communication. The client-side application must use this WebSocket endpoint for all call lifecycle events and WebRTC negotiation.

### 1\. Connection and Endpoint

- **Endpoint URL:**
  The WebSocket connection must be opened to the URL structure:

  ```
  ws/calls/<CALL_ID>/
  ```

  Where `<CALL_ID>` is the unique identifier for the specific call you are joining (e.g., `ws://server.com/ws/calls/123456789/`).

The WebSocket connection must be established securely and requires user authentication using a **Knox token**.

### Connection Endpoint

| Parameter          | Value                                       |
| :----------------- | :------------------------------------------ |
| **Protocol**       | `ws` (HTTP) or `wss` (HTTPS)                |
| **Endpoint**       | `/ws/calls/<CALL_ID>`                       |
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

## 2\. Client-to-Server Event Protocol (Outgoing Messages)

All outgoing messages must be sent as a **JSON object** containing a mandatory `"type"` field from the `CLIENT_EVENT_TYPES` list. The server's `receive_json` method handles the routing based on this field.

### A. Call Lifecycle Management

| Event Type     | Purpose                                                                          | Payload Structure (`type: ...`)                                                         |
| :------------- | :------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------- | ---------- |
| `join_call`    | Notify the call group that this user has successfully joined the call.           | `{ "type": "join_call", "data": {} }`                                                   |
| `leave_call`   | Notify the call group that this user is leaving the call.                        | `{ "type": "leave_call", "data": {} }`                                                  |
| `end_call`     | Signal all participants that the call has ended (usually initiated by the host). | `{ "type": "end_call", "data": {} }`                                                    |
| `invite_users` | Invite one or more users to join the call via notifications.                     | `{ "type": "invite_users", "user_ids": ["user_a_id", "user_b_id"], "call_type": "video" | "audio" }` |

### B. WebRTC Signaling (P2P Setup)

These events are crucial for exchanging the data needed to establish a direct, peer-to-peer (P2P) connection between users.

| Event Type      | Purpose                                              | Payload Structure (`type: ...`)                            |
| :-------------- | :--------------------------------------------------- | :--------------------------------------------------------- |
| `webrtc_offer`  | Send the Session Description Protocol (SDP) Offer.   | `{"type": "webrtc_offer", "offer": <SDP_Object>}`          |
| `webrtc_answer` | Send the Session Description Protocol (SDP) Answer.  | `{"type": "webrtc_answer", "answer": <SDP_Object>}`        |
| `ice_candidate` | Send network connection information (ICE Candidate). | `{"type": "ice_candidate", "ice_candidate": <ICE_Object>}` |

### C. In-Call State & Reactions

| Event Type      | Purpose                                                          | Payload Structure (`type: ...`)                                                                                                                   |
| :-------------- | :--------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------ |
| `media_state`   | Inform the group about changes to the user's audio/video status. | `{"type": "media_state", "audio": {"enabled": bool, "muted": bool}, "video": {"enabled": bool, "muted": bool}, "screen": {"sharing": bool}, ...}` |
| `user_reaction` | Send an emoji reaction (e.g., hand-raise, clap).                 | `{"type": "user_reaction", "reaction": "<EMOJI>", "timestamp": "..."}`                                                                            |

---

## 3\. Server-to-Client Event Protocol (Incoming Messages)

All incoming messages from the server are JSON objects representing events that occurred in the call group. You must listen for the message's `"type"` field (which corresponds to the `BACKEND_EVENT_TYPES` list) and process the payload found in the `"data"` field.

### A. Call Lifecycle Notifications

| Event Type    | Purpose                                                                    | Data Payload Key Information                                                           |
| :------------ | :------------------------------------------------------------------------- | :------------------------------------------------------------------------------------- |
| `user_joined` | A new user has entered the call group.                                     | `user_id`, `username`, **`call_state`** (Full summary of all participants for context) |
| `user_left`   | A user has intentionally left the call.                                    | `user_id`, `username`, `call_id`                                                       |
| `end_call`    | The call has been ended by another participant.                            | `user_id` (the one who ended it), `username`                                           |
| `call_joined` | **Confirmation** to the _joining_ user that they have successfully joined. | `call_id`, **`call_state`** (Your initial view of the call)                            |

### B. WebRTC Signaling Notifications

These events are the core of establishing the P2P connection. Your WebRTC implementation must process these to set up the peer connection.

| Event Type                               | Purpose                                                                                 | Action for Client                                                                                 |
| :--------------------------------------- | :-------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------ |
| `webrtc_offer`                           | Received an SDP **Offer** from another user.                                            | Use the `offer` data to set the **Remote Description** and then generate/send back an **Answer**. |
| `webrtc_answer`                          | Received an SDP **Answer** in response to your Offer.                                   | Use the `answer` data to set the **Remote Description**.                                          |
| `ice_candidate`                          | Received an ICE candidate from another user.                                            | Add the received `ice_candidate` to your **RTCPeerConnection**.                                   |
| `user_connecting` / `user_disconnecting` | Initial connection/disconnection event (before/after `join_call`/`leave_call` actions). | Update your local list of peers/presence indicators.                                              |

### C. State and Reaction Updates

| Event Type            | Purpose                                                         | Data Payload Key Information                                                           |
| :-------------------- | :-------------------------------------------------------------- | :------------------------------------------------------------------------------------- |
| `media_state_changed` | A user has changed their audio, video, or screen-sharing state. | `user_id`, `username`, **`media`** (Contains the new audio/video/screen state objects) |
| `user_reacted`        | A user has sent a reaction (e.g., 👍).                          | `user_id`, `username`, **`reaction`** (The emoji string)                               |

### Important Note on Self-Exclusion:

The consumer handlers (`user_joined`, `webrtc_offer`, etc.) are written to prevent sending a message back to the user who originated it. You should still ensure your application logic handles this gracefully, but the server attempts to filter for the sender using:

```python
if event["data"]["user_id"] == str(self.user and self.user.id or ""):
    return # Ignore the event since it was sent by the sender.
```
