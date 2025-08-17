require("dotenv").config();

const isProd = process.env.NODE_ENV === "production";

module.exports = {
  isProd,
  KEYCLOAK_BASE_URL: process.env.KEYCLOAK_BASE_URL,
  KEYCLOAK_REALM: process.env.KEYCLOAK_REALM,
  KEYCLOAK_CLIENT_ID: process.env.KEYCLOAK_CLIENT_ID,
  KEYCLOAK_CLIENT_SECRET: process.env.KEYCLOAK_CLIENT_SECRET,
  REDIRECT_URI: process.env.REDIRECT_URI,
  FRONTEND_REDIRECT_URI: process.env.FRONTEND_REDIRECT_URI,
  POST_LOGOUT_REDIRECT_URI: process.env.POST_LOGOUT_REDIRECT_URI,
  COOKIE_DOMAIN: process.env.COOKIE_DOMAIN,
  PORT: parseInt(process.env.PORT || "3000", 10),
};
