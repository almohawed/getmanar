const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// الحسابات التي تريد الإبقاء عليها
const keepEmails = [
  "mohawed32@getmanar.com",
  "sdf222sdf333@gmail.com",
  "mohawed32@manar.com"
];

async function run(nextPageToken) {
  const result = await admin.auth().listUsers(1000, nextPageToken);

  for (const user of result.users) {
    if (!keepEmails.includes(user.email)) {
      await admin.auth().deleteUser(user.uid);
      console.log("Deleted:", user.email || user.uid);
    } else {
      console.log("Kept:", user.email);
    }
  }

  if (result.pageToken) {
    await run(result.pageToken);
  }
}

run()
  .then(() => console.log("تم"))
  .catch(console.error);