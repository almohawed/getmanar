import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/presentation/widgets/unified_ui_kit.dart';
import '../data/student_repository.dart';

// Provider to fetch friends details
final friendsDetailsProvider = FutureProvider.family<List<User>, User>((
  ref,
  student,
) async {
  if (student.schoolId == null) return [];

  final firestore = FirebaseFirestore.instance;
  final studentRepo = ref.read(studentRepositoryProvider);

  try {
    // 1. Get friend IDs from StudentFriends subcollection
    final friendsSnapshot = await firestore
        .collection('Schools')
        .doc(student.schoolId)
        .collection('StudentFriends')
        .doc(student.id)
        .collection('Friends')
        .get();

    if (friendsSnapshot.docs.isEmpty) return [];

    final friendIds = friendsSnapshot.docs.map((doc) => doc.id).toList();

    // 2. Fetch User details for each friend
    final List<User> friends = [];
    for (final friendId in friendIds) {
      // Use repository to get student details
      try {
        final friend = await studentRepo.getStudentById(
          student.schoolId!,
          friendId,
        );
        if (friend != null) {
          friends.add(friend);
        }
      } catch (e) {
        debugPrint('Error fetching friend $friendId: $e');
      }
    }

    return friends;
  } catch (e) {
    debugPrint('Error fetching friends list: $e');
    return [];
  }
});

class FriendsListScreen extends ConsumerWidget {
  final User student;

  const FriendsListScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsDetailsProvider(student));

    return UnifiedPageScaffold(
      title: 'أصدقاء الطالب: ${student.name}',
      body: friendsAsync.when(
        data: (friends) {
          if (friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64.sp,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'لا يوجد أصدقاء مسجلون',
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'لم يتم ربط أي أصدقاء بهذا الطالب بعد',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: friends.length,
            separatorBuilder: (context, index) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final friend = friends[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      friend.name.isNotEmpty ? friend.name[0] : '?',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    friend.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  subtitle: Text(
                    friend.className ?? 'الصف غير محدد',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14.sp,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () {
                      // Navigate to friend details if needed
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('حدث خطأ: $error')),
      ),
    );
  }
}

// Extension to add className to User if it doesn't exist (assuming it might be missing in User model)
// Or we can fetch it separately. For now, assuming User model has it or we use a placeholder.
extension UserExtension on User {
  String? get className => null; // Placeholder if not in model
}
