import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as https from "https";
import * as querystring from "querystring";
import * as dotenv from "dotenv";
dotenv.config();


// Initialize the Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// --- Configuration ---
// Access the securely stored environment variables (Set via firebase functions:config:set)
const CLIENT_ID = process.env.HUAWEI_CLIENT_ID!;
const CLIENT_SECRET = process.env.HUAWEI_CLIENT_SECRET!;
if (!CLIENT_ID || !CLIENT_SECRET) {
  throw new Error("Missing Huawei env variables. Add them in functions/.env");
}


// Huawei API Endpoints
const TOKEN_URL = "oauth-login.cloud.huawei.com";
const PUSH_URL = "push-api.cloud.huawei.com";

/**
 * Helper function to get the Huawei OAuth Access Token using credentials.
 */
async function getHuaweiAccessToken(): Promise<string> {
  const postData = querystring.stringify({
    grant_type: "client_credentials",
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
  });

  const options = {
    hostname: TOKEN_URL,
    path: "/oauth2/v3/token",
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Content-Length": Buffer.byteLength(postData),
    },
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          const result = JSON.parse(data);
          if (res.statusCode === 200 && result.access_token) {
            resolve(result.access_token);
          } else {
            reject(new Error(`Token acquisition failed: ${data}`));
          }
        } catch (e) {
          reject(new Error("Failed to parse token response."));
        }
      });
    });

    req.on("error", (e) => reject(e));
    req.write(postData);
    req.end();
  });
}

/**
 * Triggers when a new comment is created on any solution (V2 Syntax).
 */
export const sendCommentNotificationHuawei = onDocumentCreated(
  "solutions/{solutionId}/comments/{commentId}",
  async (event) => {
    
    // V2 event handling: event.data is the snapshot, event.params are the path variables
    const snapshot = event.data;
    const commentData = snapshot?.data();
    const { solutionId } = event.params;

    if (!commentData) return null;

    // 1. Get Post Owner ID
    const solutionDoc = await db.collection("solutions").doc(solutionId).get();
    const solutionOwnerId = solutionDoc.data()?.ownerId;

    if (!solutionOwnerId || solutionOwnerId === commentData.userId) {
      console.log("Skipping notification: Self-comment or owner not found.");
      return null;
    }

    // 2. Get Owner's Huawei Tokens
    const ownerDoc = await db.collection("users").doc(solutionOwnerId).get();
    const pushTokens: string[] = ownerDoc.data()?.huaweiPushTokens || [];

    if (pushTokens.length === 0) {
      console.log("Owner has no Huawei tokens.");
      return null;
    }

    // 3. Get Access Token
    const accessToken = await getHuaweiAccessToken();

    // 4. Build Huawei Message Payload
    const messageBody = {
      message: {
        notification: {
          title: `${commentData.username} commented on your post!`,
          body: `"${commentData.text.substring(0, 50)}..."`,
        },
        android: {
          notification: {
            click_action: {
              type: 1,
              intent: `app://e_repairkit/post_detail?postId=${solutionId}`,
            },
          },
        },
        token: pushTokens,
      },
    };

    // 5. Send Notification
    const sendOptions = {
      hostname: PUSH_URL,
      path: `/v1/${CLIENT_ID}/messages:send`,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
    };

    return new Promise((resolve, reject) => {
      const req = https.request(sendOptions, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          console.log(`Push API Status: ${res.statusCode}, Response: ${data}`);
          res.statusCode === 200 ? resolve("Notification sent") : reject(data);
        });
      });

      req.on("error", (e) => reject(e));
      req.write(JSON.stringify(messageBody));
      req.end();
    });
  }
);