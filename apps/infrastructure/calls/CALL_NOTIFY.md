This **WebRTC Notify Consumer** handles the crucial **signaling** and **status updates** related to voice/video calls, but **not** the real-time media exchange itself (which happens on a separate `WebRTCConsumer`).

The client-side guide for interacting with the `/ws/notify/` channel.

# Client-Side Guide: WebRTC Notify WebSocket

This channel is the **personal, authenticated notification pipeline** for all WebRTC call events (invitations, status changes, etc.). It acts as a mailbox for incoming call invitations and a messenger for the direct responses.

## 1\. Connection and Grouping

Must be authenticated (via **TokenAuthMiddleware**) to connect to this channel.

| Parameter          | Value                                                                       |
| :----------------- | :-------------------------------------------------------------------------- |
| **Endpoint**       | `/ws/notify/`                                                               |
| **Authentication** | Knox Token (via query param or header)                                      |
| **Server Group**   | Automatically added to a **personal group**: `user_{user_id}_notifications` |

### Initial Server Response

Upon successful connection, you will receive a confirmation message. Handle the `4001` closure code for unauthorized attempts.

| Field             | Value/Type                             | Description                            |
| :---------------- | :------------------------------------- | :------------------------------------- |
| **`type`**        | `"connection_success"`                 | Connection established and authorized. |
| **`message`**     | `"Connected to notifications channel"` |                                        |
| **`data.events`** | `object`                               | Lists valid events for reference.      |

---

## 2\. Client-to-Server Events (Call Responses)

When you receive a call invite (via a **`direct`** message, usually), you must respond to the system by sending one of the following events. All events require the **`call_id`** field.

| Event Type (`type`)                                           | Purpose                                                                                             | Required Fields                                           |
| :------------------------------------------------------------ | :-------------------------------------------------------------------------------------------------- | :-------------------------------------------------------- |
| **`accept_call`**                                             | The user has accepted the call and is ready to join the WebRTC channel.                             | `call_id` (string, 21 chars)                              |
| **`decline_call`**                                            | The user is rejecting the call.                                                                     | `call_id` (string, 21 chars), `reason` (optional, string) |
| **`missed_call`**                                             | The call timed out on the client side, or the user failed to answer before a predetermined timeout. | `call_id` (string, 21 chars)                              |
| `busy_call` The user is busy (e.g., already in another call). | `call_id` (string, 21 chars)                                                                        |

### Structure for Sending a Response

**Example: Accepting a Call**

```json
{
	"type": "accept_call",
	"call_id": "ABCDEFG1234567890HIJK" // Must be the 21-character ID from the invite
}
```

**Example: Declining a Call**

```json
{
	"type": "decline_call",
	"call_id": "ABCDEFG1234567890HIJK",
	"reason": "In a meeting" // Optional, provides context
}
```

---

## 3\. Server-to-Client Events (Notifications)

The client will receive several distinct messages, all flowing through this channel.

### A. Direct Call Invitations and Messages (`single_user_message` / `direct`)

This is the primary way the server sends a **new call invite** directly to you, or any direct information specific to your session.

| Field             | Type                                       | Description                                                      |
| :---------------- | :----------------------------------------- | :--------------------------------------------------------------- |
| **`type`**        | **`direct`** (or client type from backend) | General direct message channel.                                  |
| **`message`**     | `string`                                   | Human-readable alert (e.g., `"Unauthorized"` on error).          |
| **`data`**        | `object`                                   | **This is where the `call_invite` payload is typically nested.** |
| **`status_code`** | `integer`                                  | HTTP-like status code.                                           |

### B. Call Status Broadcasts (via `call_*` event types)

These events notify you of a change that another participant caused, _or_ they are a confirmation that your previous action was registered by the system.

When a user in a call group changes their status, the backend often sends an event to the specific **Call Group** (`call_{call_id}`), and the `WebRTCNotifyConsumer` picks it up and forwards it.

| Event Type (`type`)  | Purpose                                                                                     | Listener Handler | Key Data Fields                            |
| :------------------- | :------------------------------------------------------------------------------------------ | :--------------- | :----------------------------------------- |
| **`call_accepted`**  | **A confirmation** (if you accepted) or **notification** (if another participant accepted). | `call_accepted`  | `call_id`, `user_id`, `username`           |
| **`call_declined`**  | **A confirmation** (if you declined) or **notification** (if another participant declined). | `call_declined`  | `call_id`, `user_id`, `username`, `reason` |
| **`call_busied`**    | Notification that a participant was busy.                                                   | `call_busied`    | `call_id`, `user_id`, `username`           |
| **`call_cancelled`** | Notification that the call initiator cancelled the call.                                    | `call_cancelled` | `call_id`, `from_user_id`, `from_username` |
| **`call_missed`**    | Notification that a participant missed the call.                                            | `call_missed`    | `call_id`, `user_id`, `username`           |
| **`call_ringing`**   | Notification that a participant is currently ringing.                                       | `call_ringing`   | `call_id`, `user_id`, `username`           |

---

## 4\. Overall Call Flow Overview

This channel is part of a larger, two-channel system :

1.  **Incoming Call:** The client receives a **call invite payload** via a **`single_user_message`** (or **`direct`**) event on the `/ws/notify/` channel.
2.  **Client Response:** The user clicks "Accept" or "Decline." The client sends a **`accept_call`** or **`decline_call`** event back through this `/ws/notify/` channel.
3.  **Status Broadcast:** The server updates the database, then broadcasts the status change (`call_accepted`, `call_declined`) to all participants (via the separate `WebRTCConsumer`'s call group, which is then often echoed back to this notify consumer).
4.  **Media Connection:** If accepted, the client must then connect to the dedicated **`/ws/calls/{call_id}/`** channel to handle the actual WebRTC offer/answer, ICE candidates, and media signaling.
