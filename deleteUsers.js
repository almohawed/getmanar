const admin = require("firebase-admin");

admin.initializeApp({
  credential: admin.credential.cert(require("./serviceAccountKey.json"))
});

// 🔒 الإيميلات اللي ما راح تنحذف
const keepEmails = [
  "mohawed32@manar.com",
  "sdf222sdf333@gmail.com",
  "mohawed32@getmanar.com"
];

async function deleteAllExcept(nextPageToken) {
  const listUsersResult = await admin.auth().listUsers(1000, nextPageToken);

  const usersToDelete = listUsersResult.users.filter(
    user => !keepEmails.includes(user.email)
  );

  const uidsToDelete = usersToDelete.map(user => user.uid);

  if (uidsToDelete.length > 0) {
    await admin.auth().deleteUsers(uidsToDelete);
    console.log(`Deleted ${uidsToDelete.length} users`);
  }

  if (listUsersResult.pageToken) {
    await deleteAllExcept(listUsersResult.pageToken);
  }
}

// تشغيل
deleteAllExcept();