require("dotenv").config();
const express = require("express");
const http = require("http");
const axios = require("axios");
const querystring = require("querystring");
const cors = require("cors");
const cookieParser = require("cookie-parser");
const { setupQuizWebSocket } = require("./src/sockets/quizSocket");
const { buildQuizRouter } = require("./src/routes/quizRoutes");

const app = express();
const server = http.createServer(app);
const bus = setupQuizWebSocket(server);
app.use(cors({ origin: /http:\/\/localhost:\d+/, credentials: true }));
app.use(express.json());
app.use(cookieParser());

const userRoles = {}; // key: user_id (sub), value: role

const {
  KEYCLOAK_BASE_URL,
  KEYCLOAK_REALM,
  KEYCLOAK_CLIENT_ID,
  KEYCLOAK_CLIENT_SECRET,
  REDIRECT_URI,
  FRONTEND_REDIRECT_URI,
  FRONTEND_LOGOUT_REDIRECT_URI,
  POST_LOGOUT_REDIRECT_URI,
} = process.env;

const isProd = process.env.NODE_ENV === "production";
const cookieBaseOpts = {
  httpOnly: true,
  secure: isProd, // set true behind HTTPS in production
  sameSite: isProd ? "none" : "lax",
  path: "/",
  ...(process.env.COOKIE_DOMAIN ? { domain: process.env.COOKIE_DOMAIN } : {}),
};

// Utility: detect if a URI is an http(s) URL (vs custom scheme like com.app://)
const isHttpUrl = (uri) => /^https?:\/\//i.test(uri || "");

// [1] Redirect to Keycloak Login
app.get("/login", (req, res) => {
  const authUrl =
    `${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/auth?` +
    querystring.stringify({
      client_id: KEYCLOAK_CLIENT_ID,
      response_type: "code",
      redirect_uri: REDIRECT_URI,
      scope: "openid profile email",
    });

  res.redirect(authUrl);
});

// [2] Handle OAuth2 Callback
app.get("/callback", async (req, res) => {
  const { code } = req.query;

  if (!code) return res.status(400).send("No code provided");

  try {
    // Exchange code for token
    const tokenResponse = await axios.post(
      `${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token`,
      querystring.stringify({
        grant_type: "authorization_code",
        code,
        redirect_uri: REDIRECT_URI,
        client_id: KEYCLOAK_CLIENT_ID,
        client_secret: KEYCLOAK_CLIENT_SECRET,
      }),
      { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
    );

    const { access_token, refresh_token, id_token } = tokenResponse.data;

    // Decode token (optional) or fetch user info
    const userInfo = await axios.get(
      `${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/userinfo`,
      {
        headers: {
          Authorization: `Bearer ${access_token}`,
        },
      }
    );

    // Store tokens in HTTP-only cookies so server can revoke/clear on logout
    // Note: Consider not storing access_token if you don't need it server-side.
    try {
      if (access_token) {
        res.cookie("kc_access_token", access_token, {
          ...cookieBaseOpts,
          // optionally set a short maxAge aligned with access token TTL
        });
      }
      if (refresh_token) {
        res.cookie("kc_refresh_token", refresh_token, {
          ...cookieBaseOpts,
        });
      }
      if (id_token) {
        res.cookie("kc_id_token", id_token, {
          ...cookieBaseOpts,
        });
      }
    } catch (e) {
      console.warn("Failed setting cookies:", e.message);
    }

    // Send to frontend: if FRONTEND_REDIRECT_URI is a web URL, redirect there.
    // If it's a custom scheme (mobile deep link), render an HTML page that attempts
    // to open the app and provides a clickable fallback.
    const target = `${FRONTEND_REDIRECT_URI}?access_token=${encodeURIComponent(
      access_token
    )}`;

    if (isHttpUrl(FRONTEND_REDIRECT_URI)) {
      return res.redirect(target);
    }

    // HTML fallback for custom scheme deep link
    return res.send(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Opening your app…</title>
    <style>
      body { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin: 2rem; line-height: 1.5; }
      .box { max-width: 640px; margin: auto; padding: 1.25rem; border: 1px solid #e5e7eb; border-radius: 12px; }
      .btn { display: inline-block; margin-top: .75rem; background: #111827; color: #fff; padding: .6rem 1rem; border-radius: 8px; text-decoration: none; }
      code { background: #f3f4f6; padding: .1rem .3rem; border-radius: 4px; }
    </style>
    <script>
      window.addEventListener('load', function() {
        // Try to open the mobile app deep link automatically
        setTimeout(function(){ window.location.href = ${JSON.stringify(
          target
        )}; }, 150);
      });
    </script>
  </head>
  <body>
    <div class="box">
      <h1>Sign-in complete</h1>
      <p>We are opening your app now. If nothing happens, click the button below.</p>
      <p><a class="btn" href="${target}">Open the App</a></p>
      <p style="color:#6b7280; font-size: .9rem;">Tip: For browser testing, set <code>FRONTEND_REDIRECT_URI</code> to an http(s) URL (e.g. <code>http://localhost:3000/success</code>), then refresh.</p>
    </div>
  </body>
  </html>`);
  } catch (err) {
    console.error("Callback error:", err.response?.data || err.message);
    res.status(500).send("Login failed");
  }
});

// [3] (Opsional) Terima Role dari Flutter
app.post("/select-role", async (req, res) => {
  const { access_token, selected_role } = req.body;

  if (!access_token || !selected_role) {
    return res
      .status(400)
      .json({ message: "access_token and selected_role required" });
  }

  try {
    // Ambil userinfo dari Keycloak berdasarkan access_token
    const userinfoRes = await axios.get(
      `${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/userinfo`,
      { headers: { Authorization: `Bearer ${access_token}` } }
    );
    const ui = userinfoRes.data || {};
    const sub = ui.sub;
    if (!sub) return res.status(401).json({ message: "invalid token" });

    const displayName = ui.name || ui.preferred_username || ui.email || sub;

    // Simpan role yang dipilih
    userRoles[sub] = selected_role;

    return res.json({
      message: `Role "${selected_role}" set for ${displayName}`,
      user: {
        id: sub,
        name: displayName,
        email: ui.email ?? null,
        preferred_username: ui.preferred_username ?? null,
      },
      role: selected_role,
    });
  } catch (error) {
    console.error(
      "select-role failed",
      error?.response?.data || error?.message
    );
    return res.status(500).json({ message: "failed to set role" });
  }
});

// [4] Logout: end Keycloak session and redirect back
app.get("/logout", async (req, res) => {
  try {
    // Revoke tokens if present, then end the Keycloak SSO session and clear cookies
    const { kc_access_token, kc_refresh_token, kc_id_token } =
      req.cookies || {};

    // Revoke refresh token first (primary revocation target)
    if (kc_refresh_token) {
      try {
        await axios.post(
          `${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/revoke`,
          querystring.stringify({
            token: kc_refresh_token,
            token_type_hint: "refresh_token",
            client_id: KEYCLOAK_CLIENT_ID,
            client_secret: KEYCLOAK_CLIENT_SECRET,
          }),
          { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
        );
      } catch (e) {
        console.warn(
          "Refresh token revoke failed:",
          e.response?.data || e.message
        );
      }
    }

    // Optionally revoke access token too
    if (kc_access_token) {
      try {
        await axios.post(
          `${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/revoke`,
          querystring.stringify({
            token: kc_access_token,
            token_type_hint: "access_token",
            client_id: KEYCLOAK_CLIENT_ID,
            client_secret: KEYCLOAK_CLIENT_SECRET,
          }),
          { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
        );
      } catch (e) {
        console.warn(
          "Access token revoke failed:",
          e.response?.data || e.message
        );
      }
    }

    // Compute redirect URI using POST_LOGOUT_REDIRECT_URI if provided
    const postLogoutRedirect =
      (isHttpUrl(POST_LOGOUT_REDIRECT_URI) && POST_LOGOUT_REDIRECT_URI) ||
      "http://localhost:3000/logout-complete";

    // Build end-session URL, include id_token_hint when available for silent logout
    const endSessionUrl =
      `${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/logout?` +
      `post_logout_redirect_uri=${encodeURIComponent(postLogoutRedirect)}` +
      `&client_id=${encodeURIComponent(KEYCLOAK_CLIENT_ID)}` +
      (kc_id_token ? `&id_token_hint=${encodeURIComponent(kc_id_token)}` : "");

    // Clear cookies on our domain (must match cookie options)
    const clearOpts = { ...cookieBaseOpts };
    res.clearCookie("kc_access_token", clearOpts);
    res.clearCookie("kc_refresh_token", clearOpts);
    res.clearCookie("kc_id_token", clearOpts);

    // Redirect to Keycloak to end browser SSO session
    res.redirect(endSessionUrl);
  } catch (err) {
    console.error("Logout error:", err.response?.data || err.message);
    res.status(500).send("Logout failed");
  }
});

// Optional confirmation page for manual testing
app.get("/logout-complete", (req, res) => {
  // Prefer explicit logout deep link, else derive from FRONTEND_REDIRECT_URI's scheme
  let deepLink = FRONTEND_LOGOUT_REDIRECT_URI;
  if (!deepLink && !isHttpUrl(FRONTEND_REDIRECT_URI)) {
    try {
      const u = new URL(FRONTEND_REDIRECT_URI);
      // Build scheme://login for bringing user back to app LoginPage
      deepLink = `${u.protocol}//login`;
    } catch (_) {
      // ignore
    }
  }

  if (!deepLink) {
    // Fallback simple message (web-only setups)
    return res.send(
      "You have been logged out. You can close this tab and return to the app."
    );
  }

  // Simple HTML that auto-redirects back to the app via custom scheme
  res.send(`<!doctype html>
  <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>Logged out</title>
      <style>
        body { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin: 2rem; line-height: 1.5; }
        .box { max-width: 640px; margin: auto; padding: 1.25rem; border: 1px solid #e5e7eb; border-radius: 12px; }
        .btn { display: inline-block; margin-top: .75rem; background: #111827; color: #fff; padding: .6rem 1rem; border-radius: 8px; text-decoration: none; }
        code { background: #f3f4f6; padding: .1rem .3rem; border-radius: 4px; }
      </style>
      <script>
        window.addEventListener('load', function() {
          setTimeout(function(){ window.location.href = ${JSON.stringify(
            deepLink
          )}; }, 150);
        });
      </script>
    </head>
    <body>
      <div class="box">
        <h1>Logged out</h1>
        <p>We are returning you to the app’s login screen.</p>
        <p><a class="btn" href="${deepLink}">Back to App</a></p>
        <p style="color:#6b7280; font-size: .9rem;">If nothing happens, tap the button.</p>
      </div>
    </body>
  </html>`);
});

// Simple success page for web testing
app.get("/success", (req, res) => {
  const { access_token } = req.query;
  res.send(`<!doctype html>
  <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>Login Success</title>
      <style>
        body { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin: 2rem; line-height: 1.5; }
        .box { max-width: 720px; margin: auto; padding: 1.25rem; border: 1px solid #e5e7eb; border-radius: 12px; }
        code { background: #f3f4f6; padding: .25rem .4rem; border-radius: 4px; display: inline-block; word-break: break-all; }
        .muted { color: #6b7280; font-size: .9rem; }
        .btn { display:inline-block; margin-top: 1rem; background:#111827; color:#fff; padding:.6rem 1rem; border-radius:8px; text-decoration:none; }
      </style>
    </head>
    <body>
      <div class="box">
        <h1>Login successful</h1>
        <p class="muted">This page is for local testing only. Don’t expose access tokens in URLs in production.</p>
        ${
          access_token
            ? `<p>access_token:</p><code>${access_token}</code>`
            : `<p>No token found in query string.</p>`
        }
        <p><a class="btn" href="/logout">Logout</a></p>
      </div>
    </body>
  </html>`);
});

// Initialize WebSocket for quiz functionality

// Quiz REST routes (dosen & mahasiswa)
app.use("/api", buildQuizRouter(bus));

// Start Server
const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;
server.listen(PORT, () => {
  console.log(`BFF server running at http://localhost:${PORT}`);
  console.log(`WebSocket endpoint at ws://localhost:${PORT}/ws`);
});
