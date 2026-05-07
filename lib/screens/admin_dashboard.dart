import 'package:flutter/material.dart';
import '../services/mock_data.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, ${appAdmin.name}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Text('Total users: ${users.length}'),
            Text('Total clubs: ${clubs.length}'),
            Text('Total events: ${events.length}'),
            Text('Total posts: ${newsPosts.length}'),
            const SizedBox(height: 24),
            Text('You have full control over all clubs and admins.'),
          ],
        ),
      ),
    );
  }
}
