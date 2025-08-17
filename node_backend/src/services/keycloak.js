const axios = require("axios");
const querystring = require("querystring");
const {
  KEYCLOAK_BASE_URL,
  KEYCLOAK_REALM,
  KEYCLOAK_CLIENT_ID,
  KEYCLOAK_CLIENT_SECRET,
} = require("../config/env");

async function tokenExchange({ grant_type, code, redirect_uri }) {
  return axios.post(
    `${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token`,
    querystring.stringify({
      grant_type,
      code,
      redirect_uri,
      client_id: KEYCLOAK_CLIENT_ID,
      client_secret: KEYCLOAK_CLIENT_SECRET,
    }),
    { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
  );
}

async function userInfo(accessToken) {
  return axios.get(
    `${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/userinfo`,
    { headers: { Authorization: `Bearer ${accessToken}` } }
  );
}

async function revokeToken(token, hint) {
  return axios.post(
    `${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/revoke`,
    querystring.stringify({
      token,
      token_type_hint: hint,
      client_id: KEYCLOAK_CLIENT_ID,
      client_secret: KEYCLOAK_CLIENT_SECRET,
    }),
    { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
  );
}

function endSessionUrl({ postLogoutRedirectUri, idTokenHint }) {
  const url = new URL(
    `${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/logout`
  );
  url.searchParams.set("post_logout_redirect_uri", postLogoutRedirectUri);
  url.searchParams.set("client_id", KEYCLOAK_CLIENT_ID);
  if (idTokenHint) url.searchParams.set("id_token_hint", idTokenHint);
  return url.toString();
}

module.exports = { tokenExchange, userInfo, revokeToken, endSessionUrl };
