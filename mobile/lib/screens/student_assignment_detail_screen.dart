import 'package:flutter/material.dart';

class StudentAssignmentDetailScreen extends StatelessWidget {
  const StudentAssignmentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final title = args['title'] ?? 'Assignment';
    final description = args['description'] ?? 'No description provided';
    final dueDate = args['due_date'] ?? '--';
    final status = args['status'] ?? 'pending';

    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'missing':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// TITLE
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            /// STATUS + DUE DATE
            Row(
              children: [
                Chip(
                  label: Text(status.toUpperCase()),
                  backgroundColor: statusColor.withOpacity(0.2),
                  labelStyle: TextStyle(color: statusColor),
                ),
                const SizedBox(width: 10),
                Text("Due: $dueDate"),
              ],
            ),

            const SizedBox(height: 20),

            /// DESCRIPTION
            const Text(
              "Description",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// SUBMIT BUTTON (optional future)
            if (status != 'completed')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Submission feature coming soon"),
                      ),
                    );
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Submit Assignment"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
