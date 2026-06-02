# Share links: Safari error and how to fix it

This document describes why opening a shared post URL in **Safari** can show a JSON error, how that differs from opening the link **in the app**, and what to change on the **server** vs in the **mobile app**.

---

## Symptoms

When you paste or tap a share URL like:

`https://omeeba.co.in/share/post/<postId>`

**Safari** may display raw JSON instead of a web page, for example:

```json
{
  "success": false,
  "message": "Not Found - /share/post/<postId>",
  "errorType": "Not Found",
  "error": "Route /share/post/<postId> not found",
  "data": null
}
```

The same link might still **open the app** correctly when Universal Links / App Links are configured, because the OS can hand the URL to the app without loading the full page in Safari.

---

## What the issue is

### Not a bug in the iPhone or Flutter share sheet

The message **“Route … not found”** means the **web server** (or API gateway in front of `omeeba.co.in`) received an HTTP request for the path `/share/post/<postId>` and **has no handler** for that route as a **browser** request.

Many backends expose only **REST API** routes (e.g. `/api/v1/...`). Paths like `/share/post/...` are often intended for:

- **Marketing / web**: a real HTML page (or redirect), or  
- **Deep linking**: the same path in **Universal Links** / **Android App Links** so the OS opens the app.

If there is **no web route** and the server’s fallback is “API-style 404 JSON,” Safari users will see that JSON.

### Why the app can still work

- **Universal Links (iOS)** and **App Links (Android)** use the **same URL** but are validated with files hosted on the domain (`apple-app-site-association`, `assetlinks.json`). The OS may open the **app** without relying on a pretty HTML page.
- **Safari**, when used to **open the URL explicitly**, performs a normal **GET** and expects whatever the server returns for that path—often **HTML**, not an API error.

So the problem is **missing or incorrect web (or redirect) behavior** for `/share/post/:id`, not the mobile share implementation by itself.

---

## How to fix it

### 1. Backend / website (required for Safari and for good UX)

Implement one of the following for `GET https://omeeba.co.in/share/post/<postId>` (and the same for other share types if you use them, e.g. write-post, zeal):

| Approach | Description |
|----------|-------------|
| **Static or SSR page** | Return **HTML** with basic content, Open Graph tags for previews, and a clear “Open in app” or store link. |
| **Redirect** | **301/302** to a URL that already works in the browser (e.g. another path your web app serves). |
| **SPA fallback** | If you use a single-page app, configure the host so `/share/post/*` is routed to the SPA and the client renders a share landing page. |

Ensure the response is **not** only a JSON 404 from the API layer for paths you advertise as **public share URLs**.

### 2. Apple Universal Links — `apple-app-site-association`

- Host the file at (for example)  
  `https://omeeba.co.in/.well-known/apple-app-site-association`
- Include path patterns that match your real share URLs, e.g.:

  - `/share/*`  
  - or more specific patterns like `/share/post/*`, `/share/write-post/*`, `/share/zeal/*`

If `paths` excludes `/share/post/...`, iOS may not associate those URLs with the app.

### 3. Android App Links — `assetlinks.json`

- Same idea: declare the host and path scope so `/share/post/...` is covered if you use those URLs for links.

### 4. Mobile app (this repo)

- **Share URLs** often come from the API field `shareableLink`. The app passes that through to copy/share; the **format** is defined by the **backend**.
- **`DeepLinkService`** (`lib/core/services/deep_link_service.dart`) parses paths such as `/share/post/{id}`, `/share/write-post/{id}`, `/share/zeal/{id}` for supported **Omeeba hosts** (including `omeeba.co.in` and `omeeba.app`).
- Fixing Safari’s JSON error still requires **server-side** routing or HTML as above; the app cannot change what Safari receives from `omeeba.co.in`.

---

## Quick checklist

| Check | Action |
|-------|--------|
| Safari shows JSON 404 | Add web route, redirect, or HTML for `/share/post/:id` on `omeeba.co.in`. |
| Link opens app but not from Safari | Verify AASA / assetlinks paths include `/share/...`. |
| Link never opens app | Verify entitlements, App ID capabilities, correct bundle ID in AASA, HTTPS, no bad redirects on AASA URL. |
| In-app navigation from link fails | Confirm `DeepLinkService` host list includes your production domain and path segments match `/share/...`. |

---

## Related files in this project

| File | Role |
|------|------|
| `lib/core/services/deep_link_service.dart` | Parses `https://…/share/...` and navigates inside the app after login. |
| `lib/presentation/main/home/widgets/share_bottom_sheet.dart` | Copy / system share; uses `shareUrl` or a default post URL. |
| `ios/Runner/Runner.entitlements` | `applinks:` entries for Universal Links. |
| API models (e.g. `shareableLink` on posts) | Source of the exact URL users copy and share. |

---

## Summary

- **Issue:** The server returns an **API-style “route not found” JSON** for `/share/post/...` when Safari loads the URL.  
- **Fix:** Provide a **proper HTTP response** for that path (HTML, redirect, or SPA route), and align **AASA / assetlinks** `paths` with your share URLs.  
- **App:** Ensures in-app handling of the same URLs on supported hosts; it does **not** replace a web response for Safari.
