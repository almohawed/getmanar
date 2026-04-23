import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/distinguished_repository.dart';
import '../domain/distinguished_nomination.dart';

class DistinguishedStudentsWidget extends ConsumerWidget {
  final String schoolId;

  const DistinguishedStudentsWidget({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (schoolId.isEmpty) {
      return const SizedBox.shrink();
    }
    final repo = ref.watch(distinguishedRepositoryProvider);

    return StreamBuilder<List<DistinguishedNomination>>(
      stream: repo.watchPublishedStudents(schoolId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // Hide if no data
        }

        final students = snapshot.data!;
        // Check if we are within the 1 week display window?
        // Logic handled here or in stream. Stream currently returns all final.
        // We should check 'publishedAt' of the cycle, but we only have nominations here.
        // For MVP, show all 'final' nominations.
        // Ideally, fetch active published cycle first.

        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'الطلاب المتميزين لهذا الأسبوع',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.star, color: Colors.white),
                  ],
                ),
              ),
              Container(
                height: 150, // Fixed height for scrolling list
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Container(
                      width: 120,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              student.studentName.isNotEmpty
                                  ? student.studentName[0]
                                  : '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            student.studentName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            student.gradeLevel,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
