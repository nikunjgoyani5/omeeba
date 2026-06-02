# Omeeba Postman Collection Verification

**Date:** January 31, 2026  
**Collection:** Omeeba.postman_collection.json  
**App:** Omeeba Flutter (omeeba_new)

---

## 1. Executive Summary

| Aspect                     | Status          | Notes                                                                                                             |
|----------------------------|-----------------|-------------------------------------------------------------------------------------------------------------------|
| **Collection vs App Flow** | ✅ Aligned       | Postman covers all flows implied by the app UI (auth, profile, posts, zeals, chat, explore, notifications, etc.). |
| **App API Integration**    | ❌ Not wired     | App does **not** call these APIs yet. Auth, base URL, and endpoints are empty or mock.                            |
| **Collection Quality**     | ⚠️ Minor issues | Inconsistent auth variable (`authToken` vs `token`), some hardcoded IDs, missing env docs.                        |

**Verdict:** The Postman collection **matches** the app’s intended flow and feature set. To use it with the app, you need to (1) fix the small collection issues below and (2) integrate the APIs in the Flutter app (base URL, endpoints, and auth/API calls in controllers).

---

## 2. App Flow vs Postman Collection Mapping

### 2.1 App Routes / Screens (from `app_routes.dart` & `app_pages.dart`)

| App Route              | Screen                             | Postman Section                                                                    | Match        |
|------------------------|------------------------------------|------------------------------------------------------------------------------------|--------------|
| `/`                    | Splash                             | —                                                                                  | N/A (no API) |
| `/login`               | Login                              | **Auth → Login**                                                                   | ✅            |
| `/signUp`              | Signup                             | **Auth → Register**                                                                | ✅            |
| —                      | OTP Verification                   | **Auth → Verify OTP**, **Resend OTP**                                              | ✅            |
| —                      | Forgot Password                    | **Auth → Forgot Password**                                                         | ✅            |
| —                      | Reset Password                     | **Auth → Reset Password**                                                          | ✅            |
| `/dashboard`           | Dashboard (tabs)                   | Multiple sections                                                                  | ✅            |
| `/dashboard` → Home    | Home feed                          | **Home → Zeels**, **Home-feed**                                                    | ✅            |
| `/dashboard` → Notify  | Notifications                      | **Notifications** (get, unread-count, read, read-all)                              | ✅            |
| `/dashboard` → Post    | Create post entry                  | **Post → Upload post**, **Write post → Upload post**                               | ✅            |
| `/dashboard` → Zeel    | Zeals feed                         | **Zeals** (upload, create, status)                                                 | ✅            |
| `/dashboard` → Profile | My profile                         | **User profile** (get/update profile, posts, write-posts, polls, mentioned-posts)  | ✅            |
| `/setting`             | Settings                           | **Auth → Change password**, **Subscriptions** (optional)                           | ✅            |
| `/explore`             | Explore                            | **Explore** (trending, search, hashtags)                                           | ✅            |
| `/chat`                | Chat list                          | **Chat** (Create/Get Room, Get Chat Rooms, Room by ID, Unread counts, Delete Room) | ✅            |
| `/chatDetails`         | Chat details                       | Same Chat APIs + messaging (if present in backend)                                 | ✅            |
| `/userProfileView`     | Other user profile                 | **User profile** (get profile, posts) + **Follow - Unfollow**                      | ✅            |
| `/createPost`          | Create post (write/post/zeal/poll) | **Write post**, **Post**, **Zeals**, **Poll**                                      | ✅            |
| `/postDetails`         | Post detail                        | **Content likes**, **Comments**, **Share**, **Save**, **Report**                   | ✅            |

### 2.2 Feature-to-API Mapping

| App Feature       | Postman Requests                                                                                                                                                     |
|-------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Auth**          | Register, Verify OTP, Resend OTP, Login, Forgot Password, Reset Password, Change password                                                                            |
| **Profile**       | Update profile (form-data), Get user profile, Get user posts, Get user write posts, Get user polls, Get mentioned-posts                                              |
| **Posts**         | Upload post (form-data: caption, images, mentionedUserIds, musicId, musicStartTime, musicEndTime)                                                                    |
| **Write posts**   | Upload write post (JSON: content, mentionedUserIds)                                                                                                                  |
| **Zeals**         | 1. Upload file (zeals/upload), 2. Create Zeal post (zeals), 3. Get Zeal status (zeals/:id/status)                                                                    |
| **Polls**         | Create poll, Vote poll, Get poll                                                                                                                                     |
| **Follow**        | Follow User, Unfollow User, Check Follow Status, Get My Followers, Get Followers (Specific User), Get My Following, Get Following (Specific User), Get Count, Search |
| **Comments**      | Create (Post/Write/Zeal), Get Comments, Get Single Comment, Delete, Like/Unlike, Report; **Replies**: Create, Get                                                    |
| **Mentions**      | Search Users for Mentions                                                                                                                                            |
| **Likes**         | like-unlike toggle                                                                                                                                                   |
| **Save**          | save-unsaved toggle, Get saved status, Get user's saved content list                                                                                                 |
| **Share**         | Share, Sent, Received, Get share count, Get eligible users                                                                                                           |
| **Report**        | Categories (all, with-subcategories, sub by category), Report Submission (Post, Write Post, Zeal Post)                                                               |
| **Explore**       | Explore trending, Explore search, Hashtags (trend)                                                                                                                   |
| **Chat**          | Create/Get Room, Get Chat Rooms, Get Room by ID, Room Unread Count, Total Unread Count, Delete Room                                                                  |
| **Snaps**         | View Snap, Snaps Inbox, Sent Snaps                                                                                                                                   |
| **Subscriptions** | Verify apple, Verify google, Restore purchases, Verify purchases status                                                                                              |
| **Notifications** | Get notifications, unread-count, read single, read all                                                                                                               |

The collection **covers** the app’s flow and UI; no major missing sections were found.

---

## 3. Issues in the Postman Collection

### 3.1 Critical / Must Fix

| # | Issue                                                | Location                                                           | Recommendation                                                                                                                                                                                                                                                 |
|---|------------------------------------------------------|--------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | **Auth variable inconsistency**                      | Zeals "1. Upload File", Follow "Follow User" (and possibly others) | Some requests use `Authorization: Bearer {{authToken}}` in headers; most use Postman auth with `{{token}}`. Use **one** variable (e.g. `{{token}}`) and set it from the Login response (e.g. test script: `pm.environment.set("token", jsonData.data.token)`). |
| 2 | **`base_url` and `token` not defined in collection** | Collection root                                                    | Add collection variables: `base_url` (e.g. `https://your-api.com/`) and `token` (set after Login). Document in collection description that user must run **Auth → Login** first and (optional) use a test script to set `token`.                               |

### 3.2 Should Fix

| #  | Issue                                  | Location                                                               | Recommendation                                                                                                                                                                                                                       |
|----|----------------------------------------|------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 3  | **Hardcoded Zeal IDs**                 | Zeals "2. Create Zeal Post" (zealDraftId), "3. Get Zeal Status" (path) | Use variable: e.g. `{{zealDraftId}}` and `{{zealId}}`. The collection already has test scripts that set `zealDraftId` and `zealId`; ensure the "Get Zeal Status" URL uses `{{zealId}}` (e.g. `{{base_url}}zeals/{{zealId}}/status`). |
| 4  | **Hardcoded user IDs in query params** | User profile (e.g. Get user posts, Get user write posts)               | Use `{{userId}}` or "current user" semantics where applicable; document that for "my" profile, userId can be omitted or equal to logged-in user.                                                                                     |
| 5  | **Update profile: file paths**         | User profile → Update profile                                          | `coverImage` and `profileImage` use Mac paths (`/Users/dreamworld/...`). Document that these are examples; Windows users must replace with their own paths or remove files when testing.                                             |
| 6  | **Write post vs Post**                 | Two folders: "Write post" and "Post"                                   | Clarify in folder/request descriptions: "Write post" = text/write content (JSON); "Post" = media post (form-data with caption, images, music). Matches app’s "Write" vs "Post" tabs.                                                 |
| 7  | **Content likes uses `{{token_2}}`**   | Content likes → like-unlike toggle                                     | Change to `{{token}}`.                                                                                                                                                                                                               |
| 8  | **Share → Received: hardcoded token**  | Share → Received                                                       | Replace hardcoded JWT with `{{token}}`.                                                                                                                                                                                              |
| 9  | **Explore: empty bearer value**        | Explore search, Hashtags                                               | Set bearer to `{{token}}`.                                                                                                                                                                                                           |
| 10 | **Home: hardcoded localhost**          | Home → Zeels, Home-feed                                                | Use `{{base_url}}` and path e.g. `api/v1/home`.                                                                                                                                                                                      |
| 11 | **`base_url` vs `baseUrl`**            | Follow, Report, Chat, Snaps                                            | Use one variable (e.g. `{{base_url}}`) everywhere.                                                                                                                                                                                   |
| 12 | **Chat/Snaps: mixed path style**       | Chat, Snaps                                                            | Unify to one base and path convention.                                                                                                                                                                                               |
| 13 | **Poll: hardcoded poll ID**            | Vote poll, Get poll                                                    | Use `{{pollId}}` variable.                                                                                                                                                                                                           |

### 3.3 Optional / Nice to Have

| #  | Issue                  | Recommendation                                                                                                                                                              |
|----|------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 14 | **Login response**     | Add a test script on **Auth → Login** to auto-set `token`: `var json = pm.response.json(); if (json.data && json.data.token) pm.environment.set("token", json.data.token);` |
| 15 | **Sample responses**   | Many requests have empty `response` arrays. Saving sample responses for key flows (Login, Get profile, Get home feed) would help frontend integration.                      |
| 16 | **CommentId / Report** | Some requests use `{{commentId}}`; ensure an environment variable is documented or set from a previous "Get Comments" / "Create Comment" response.                          |
| 17 | **Chat/Snaps auth**    | Chat and Snaps requests do not set Authorization header; add Bearer `{{token}}` if backend requires auth.                                                                   |

---

## 4. App-Side Gaps (Not Postman Issues)

These are about the **Flutter app**, not the collection:

| # | Gap                                               | Location                                                                                                                      | Recommendation                                                                                                                                                                                                                    |
|---|---------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | **No API base URL**                               | `lib/core/utils/app_constant.dart`: `baseUrlDev`, `baseUrlLive` are empty                                                     | Set `baseUrlDev` and `baseUrlLive` to your backend base URL (same as Postman `base_url`).                                                                                                                                         |
| 2 | **No endpoint constants**                         | `lib/core/services/api_endpoints.dart`: only `login = ''`                                                                     | Add constants for all endpoints used by the app (e.g. `auth/register`, `auth/login`, `auth/verify-otp`, `users/profile`, `posts`, `zeals/upload`, etc.) matching Postman paths.                                                   |
| 3 | **Auth not calling API**                          | `lib/presentation/auth/controller/auth_controller.dart`: `login()` only does `Get.offAllNamed(AppRoutes.dashboard)`           | Call `ApiClient.request()` with `auth/login` (and body: email, password); on success save token (e.g. PrefService), then navigate to dashboard. Wire Register, Verify OTP, Resend OTP, Forgot Password, Reset Password similarly. |
| 4 | **No token persistence after login**              | App uses `PrefService.getString(PrefKeys.accessToken)` in `api_service.dart` but auth never sets it                           | After successful Login (and optionally after Register + Verify OTP), save `data.token` to preferences and set it in API client headers (already implemented for requests).                                                        |
| 5 | **Chat / Home / Explore / Profile use mock data** | e.g. `chat_controller.dart`: "Simulated data - replace with actual API call"; Home/Explore/Profile controllers don’t call API | Replace with calls to Chat, Home-feed/Zeels, Explore, User profile endpoints from the Postman collection.                                                                                                                         |

---

## 5. Complete API List by Module (All Inner APIs Verified)

Every request under each section is listed below with **Method** and **Path/URL** as in the collection.

### 5.1 Follow - Unfollow

| #   | Request Name                    | Method   | Path / URL                                                                       | Auth                   |
|-----|---------------------------------|----------|----------------------------------------------------------------------------------|------------------------|
| 1   | Follow User                     | POST     | `{{base_url}}/api/v1/follow/:userId` (path var: `userId` = `{{targetUserId}}`)   | Bearer {{authToken}}   |
| 2   | Unfollow User                   | DELETE   | `{{baseUrl}}/api/v1/follow/:userId`                                              | Bearer {{authToken}}   |
| 3   | Check Follow Status             | GET      | `{{baseUrl}}/api/v1/follow/:userId/status`                                       | Bearer {{authToken}}   |
| 4   | Get My Followers                | GET      | `{{base_url}}follow/followers?page=1&limit=20` (optional: `search`)              | Bearer                 |
| 5   | Get Followers (Specific User)   | GET      | `{{base_url}}follow/followers?userId={{targetUserId}}&page=1&limit=20`           | Bearer                 |
| 6   | Get My Following                | GET      | `{{base_url}}follow/following?page=1&limit=20` (optional: `search`)              | Bearer                 |
| 7   | Get Following (Specific User)   | GET      | `{{base_url}}follow/following?userId={{targetUserId}}&page=1&limit=20`           | Bearer                 |
| 8   | Get Count                       | GET      | `{{base_url}}follow/count`                                                       | Bearer {{token}}       |
| 9   | Search                          | GET      | `{{base_url}}users/search?username=ha`                                           | Bearer {{token}}       |
| --- | ------------------------------- | -------- | -------------------------------------------------------------------------------- | ---------------------- |
**Note:** Follow/Unfollow/Check Status use `{{baseUrl}}` (capital B) and `/api/v1/follow/...`; others use `{{base_url}}follow/...`. Inconsistent.

---

### 5.2 Poll

| # | Request Name | Method | Path / URL                                                           | Auth             |
|---|--------------|--------|----------------------------------------------------------------------|------------------|
| 1 | Create poll  | POST   | `{{base_url}}polls`                                                  | Bearer {{token}} |
| 2 | Vote poll    | POST   | `{{base_url}}polls/696e05d53296432c6e0672c8/vote` (body: `optionId`) | Bearer {{token}} |
| 3 | Get poll     | GET    | `{{base_url}}polls/696e05d53296432c6e0672c8`                         | Bearer {{token}} |

**Note:** Vote poll and Get poll use hardcoded poll ID; should use `{{pollId}}`.

---

### 5.3 Report

**Categories (sub-folder):**

| # | Request Name                       | Method |                                      Path / URL                                       | Auth |
|---|------------------------------------|--------|:-------------------------------------------------------------------------------------:|------|
| 1 | Get All Categories                 | GET    |                           `{{base_url}}reports/categories`                            | None |
| 2 | Get Categories with Sub-Categories | GET    |                  `{{base_url}}reports/categories/with-subcategories`                  | None |
| 3 | Get Sub-Categories by Category ID  | GET    | `{{baseUrl}}/api/v1/reports/categories/:categoryId/subcategories` (var: `categoryId`) | None |

**Report Submission (sub-folder):**

| # | Request Name               | Method |                                  Path / URL                                  | Auth             |
|---|----------------------------|--------|:----------------------------------------------------------------------------:|------------------|
| 4 | Create Report - Post       | POST   | `{{base_url}}reports` (body: contentType, contentId, subCategoryId, details) | Bearer {{token}} |
| 5 | Create Report - Write Post | POST   | `{{base_url}}reports` (body: contentType, contentId, subCategoryId, details) | Bearer {{token}} |
| 6 | Create Report - Zeal Post  | POST   | `{{base_url}}reports` (body: contentType, contentId, subCategoryId, details) | Bearer {{token}} |

---

### 5.4 Content likes

| # | Request Name       | Method | Path / URL                                                        | Auth               |
|---|--------------------|--------|-------------------------------------------------------------------|--------------------|
| 1 | like-unlike toggle | POST   | `{{base_url}}content-likes/toggle` (body: contentType, contentId) | Bearer {{token_2}} |

**Note:** Collection uses `{{token_2}}`; should be `{{token}}` for consistency.

---

### 5.5 Comments

**Comment (sub-folder):**

| # | Request Name                 | Method | Path / URL                                                                     | Auth             |
|---|------------------------------|--------|--------------------------------------------------------------------------------|------------------|
| 1 | Create Comment on Post       | POST   | `{{base_url}}comments` (body: contentType, contentId, comment)                 | Bearer {{token}} |
| 2 | Create Comment on Write Post | POST   | `{{base_url}}comments` (body: contentType, contentId, comment)                 | Bearer {{token}} |
| 3 | Create Comment on Zeal Post  | POST   | `{{base_url}}comments` (body: contentType, contentId, comment)                 | Bearer {{token}} |
| 4 | Get Comments                 | GET    | `{{base_url}}comments?contentType=...&contentId={{contentId}}&page=1&limit=20` | Bearer {{token}} |
| 5 | Get Single Comment           | GET    | `{{base_url}}comments/{{commentId}}`                                           | Bearer {{token}} |
| 6 | Delete Comment               | DELETE | `{{base_url}}comments/{{commentId}}`                                           | Bearer {{token}} |
| 7 | Like/Unlike Comment          | POST   | `{{base_url}}comments/{{commentId}}/like`                                      | Bearer {{token}} |
| 8 | Report Comment               | POST   | `{{base_url}}comments/{{commentId}}/report` (body: subCategoryId, details)     | Bearer {{token}} |

**Mention Search (sub-folder):**

| # | Request Name              | Method | Path / URL                                       | Auth             |
|---|---------------------------|--------|--------------------------------------------------|------------------|
| 9 | Search Users for Mentions | GET    | `{{base_url}}users/mentions/search?q=h&limit=20` | Bearer {{token}} |

**Replies (sub-folder):**

| #  | Request Name | Method | Path / URL                                                   | Auth             |
|----|--------------|--------|--------------------------------------------------------------|------------------|
| 10 | Create Reply | POST   | `{{base_url}}comments/{{commentId}}/replies` (body: reply)   | Bearer {{token}} |
| 11 | Get Replies  | GET    | `{{base_url}}comments/{{commentId}}/replies?page=1&limit=20` | Bearer {{token}} |

---

### 5.6 Share

| # | Request Name                           | Method | Path / URL                                                                     | Auth                                   |
|---|----------------------------------------|--------|--------------------------------------------------------------------------------|----------------------------------------|
| 1 | Share                                  | POST   | `{{base_url}}content-shares/share` (body: contentType, contentId, receiverIds) | Bearer {{token}}                       |
| 2 | Sent                                   | GET    | `{{base_url}}content-shares/sent`                                              | Bearer {{token}}                       |
| 3 | Received                               | GET    | `{{base_url}}content-shares/received`                                          | Bearer (hardcoded token in collection) |
| 4 | Get share count                        | POST   | `{{base_url}}content-shares/count` (body: contentType, contentId)              | Bearer {{token}}                       |
| 5 | Get eligible users for content sharing | GET    | `{{base_url}}content-shares/users?search=harsh`                                | Bearer {{token}}                       |

**Note:** "Received" has a hardcoded token in body; should use `{{token}}`.

---

### 5.7 Save

| # | Request Name                               | Method |                                 Path / URL                                 | Auth             |
|---|--------------------------------------------|:------:|:--------------------------------------------------------------------------:|------------------|
| 1 | save-unsaved toggle                        |  POST  |     `{{base_url}}saved-content/toggle` (body: contentType, contentId)      | Bearer {{token}} |
| 2 | Get saved status for content               |  POST  |     `{{base_url}}saved-content/status` (body: contentType, contentId)      | Bearer {{token}} |
| 3 | Get user's saved content list with filters |  POST  | `{{base_url}}saved-content/list` (body: contentType optional, page, limit) | Bearer {{token}} |

---

### 5.8 Explore

| # | Request Name     | Method | Path / URL                                           | Auth                               |
|---|------------------|--------|------------------------------------------------------|------------------------------------|
| 1 | Explore trending | GET    | `{{base_url}}explore/trending`                       | None                               |
| 2 | Explore search   | GET    | `{{base_url}}explore/search?query=this&type=hashtag` | Bearer (value empty in collection) |
| 3 | Hashtags         | GET    | `{{base_url}}explore/hashtag/trend?contentType=post` | Bearer (value empty in collection) |

**Note:** Explore search and Hashtags have bearer token value `""`; should use `{{token}}`.

---

### 5.9 Chat

| # | Request Name           | Method | Path / URL                                                          | Auth                                       |
|---|------------------------|--------|---------------------------------------------------------------------|--------------------------------------------|
| 1 | Create / Get Room      | POST   | `{{base_url}}chat/rooms/create` (body: otherUserId, chatType)       | No Bearer in request (add if API requires) |
| 2 | Get Chat Rooms (Inbox) | GET    | `{{base_url}}chat/rooms?page=1&limit=20`                            | No Bearer in request                       |
| 3 | Get Room by ID         | GET    | `{{baseUrl}}/api/{{apiVersion}}/chat/rooms/{{roomId}}`              | No Bearer in request                       |
| 4 | Room Unread Count      | GET    | `{{baseUrl}}/api/{{apiVersion}}/chat/rooms/{{roomId}}/unread-count` | No Bearer in request                       |
| 5 | Total Unread Count     | GET    | `{{baseUrl}}/api/{{apiVersion}}/chat/unread-count`                  | No Bearer in request                       |
| 6 | Delete Room (Block)    | DELETE | `{{baseUrl}}/api/{{apiVersion}}/chat/rooms/{{roomId}}`              | No Bearer in request                       |

**Note:** Create/Get Room and Get Chat Rooms use `{{base_url}}chat/...`; Get Room by ID, unread counts, and Delete use `{{baseUrl}}/api/{{apiVersion}}/chat/...`. Variable names and path style are inconsistent. Chat requests do not set Authorization header; add Bearer if backend requires auth.

---

### 5.10 Snaps

| # | Request Name               | Method | Path / URL                                                     | Auth                 |
|---|----------------------------|--------|----------------------------------------------------------------|----------------------|
| 1 | View Snap (Get Secure URL) | GET    | `{{baseUrl}}/api/{{apiVersion}}/snaps/{{snapId}}/view`         | No Bearer in request |
| 2 | Snaps Inbox                | GET    | `{{base_url}}snaps/inbox?page=1&limit=20&includeExpired=false` | No Bearer in request |
| 3 | Sent Snaps                 | GET    | `{{base_url}}snaps/sent?page=1&limit=20`                       | No Bearer in request |

**Note:** View Snap uses `{{baseUrl}}`, `{{apiVersion}}`, `{{snapId}}`; Inbox and Sent use `{{base_url}}snaps/...`. Inconsistent base URL variable and path style.

---

### 5.11 Home

| # | Request Name | Method | Path / URL                                     | Auth             |
|---|--------------|--------|------------------------------------------------|------------------|
| 1 | Zeels        | GET    | `http://localhost:3000/api/v1/home?item=zeels` | Bearer {{token}} |
| 2 | Home-feed    | GET    | `http://localhost:3000/api/v1/home`            | Bearer {{token}} |

**Note:** Both use **hardcoded** `http://localhost:3000` instead of `{{base_url}}`. Should be `{{base_url}}api/v1/home` (or equivalent) so they work with any environment.

---

### 5.12 Subscriptions

| # | Request Name            | Method | Path / URL                                                                                   | Auth             |
|---|-------------------------|--------|----------------------------------------------------------------------------------------------|------------------|
| 1 | Verify apple            | POST   | `{{base_url}}purchases/verify/apple` (body: receiptData, productId optional)                 | Bearer {{token}} |
| 2 | Verify google           | POST   | `{{base_url}}purchases/verify/google` (body: productId optional, packageName, purchaseToken) | Bearer {{token}} |
| 3 | Restore purchases       | GET    | `{{base_url}}purchases/restore?platform=apple`                                               | Bearer {{token}} |
| 4 | Verify purchases status | GET    | `{{base_url}}purchases/status`                                                               | Bearer {{token}} |

---

### 5.13 Notifications

| # | Request Name             | Method | Path / URL                                                                  | Auth             |
|---|--------------------------|--------|-----------------------------------------------------------------------------|------------------|
| 1 | Get notifications        | GET    | `{{base_url}}notifications`                                                 | Bearer {{token}} |
| 2 | unread-count             | GET    | `{{base_url}}notifications/unread-count`                                    | Bearer {{token}} |
| 3 | read single notification | PUT    | `{{base_url}}notifications/:notificationId/read` (path var: notificationId) | Bearer {{token}} |
| 4 | read all                 | PUT    | `{{base_url}}notifications/read-all`                                        | Bearer {{token}} |

---
6. Postman Collection Structure (Quick Reference)

```
Omeeba
├── Auth (7 requests)
├── User profile (6 requests)
├── Write post (1 request)
├── Post (1 request)
├── Zeals (3 requests)
├── Follow - Unfollow (9 requests) ← full list in §5.1
├── Poll (3 requests) ← full list in §5.2
├── Report
│   ├── Categories (3 requests) ← full list in §5.3
│   └── Report Submission (3 requests)
├── Content likes (1 request) ← full list in §5.4
├── Comments
│   ├── Comment (8 requests) ← full list in §5.5
│   ├── Mention Search (1 request)
│   └── Replies (2 requests)
├── Share (5 requests) ← full list in §5.6
├── Save (3 requests) ← full list in §5.7
├── Explore (3 requests) ← full list in §5.8
├── Chat (6 requests) ← full list in §5.9
├── Snaps (3 requests) ← full list in §5.10
├── Home (2 requests) ← full list in §5.11
├── Subscriptions (4 requests) ← full list in §5.12
└── Notifications (4 requests) ← full list in §5.13
```

---

## 7. Conclusion

- **Is the Postman collection according to the app’s flow and UI?**  
  **Yes.** The collection aligns with the app’s routes and features (auth, profile, posts, write posts, zeals, polls, follow, comments, likes, save, share, report, explore, chat, snaps, home, subscriptions, notifications).

- **What to fix in Postman:**  
  Unify auth on `{{token}}`, document/set `base_url` and `token`, replace hardcoded Zeal/user IDs with variables where appropriate, and clarify Write post vs Post and file paths in Update profile.

- **What to fix in the app:**  
  Set base URL and endpoint constants, implement auth API calls and token storage, and replace mock data in Chat, Home, Explore, and Profile with the corresponding Postman APIs.

After these steps, the same backend contract used in Postman can be used consistently in the Flutter app.
