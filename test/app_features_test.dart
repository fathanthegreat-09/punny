import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3/services/api_service.dart';
import 'package:flutter_3/models/post.dart';
import 'package:flutter_3/pages/home_page.dart';
import 'package:flutter_3/pages/user_page.dart';
import 'package:flutter_3/pages/login_page.dart';
import 'package:flutter_3/pages/register_page.dart';
import 'package:flutter_3/pages/add_page.dart';
import 'package:flutter_3/pages/pin_detail_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiService unit tests', () {
    test('Follow/Unfollow user management', () {
      final api = ApiService();

      // Ensure 'Sensei' is initially followed or toggle follow works
      final initialFollowing = api.isFollowing('TestCreator');
      expect(initialFollowing, isFalse);

      // Follow
      final nowFollowing = api.toggleFollow('TestCreator');
      expect(nowFollowing, isTrue);
      expect(api.isFollowing('TestCreator'), isTrue);
      expect(api.getFollowingList().contains('TestCreator'), isTrue);

      // Unfollow
      final nowUnfollowed = api.toggleFollow('TestCreator');
      expect(nowUnfollowed, isFalse);
      expect(api.isFollowing('TestCreator'), isFalse);
    });

    test('Saved posts management', () {
      final api = ApiService();

      // Check pin-10
      final isSaved = api.isPostSaved('pin-10');
      final toggleResult = api.toggleSavePost('pin-10');
      expect(toggleResult, !isSaved);
      expect(api.isPostSaved('pin-10'), !isSaved);

      // Verify saved posts list contains or excludes
      final savedPosts = api.getSavedPosts();
      if (!isSaved) {
        expect(savedPosts.any((p) => p.id == 'pin-10'), isTrue);
      }

      // Revert back
      api.toggleSavePost('pin-10');
      expect(api.isPostSaved('pin-10'), isSaved);
    });

    test('Liked posts management', () {
      final api = ApiService();
      final currentUser = api.currentUser;

      api.toggleLocalLike('pin-3', currentUser);
      final likedPosts = api.getLikedPosts();
      expect(likedPosts.any((p) => p.id == 'pin-3'), isTrue);

      // Toggle off
      api.toggleLocalLike('pin-3', currentUser);
      final unlikedPosts = api.getLikedPosts();
      expect(unlikedPosts.any((p) => p.id == 'pin-3'), isFalse);
    });

    test('Post model multi-image support', () {
      final post = Post(
        id: 'test-multi',
        title: 'Multi Photo Pin',
        imageUrl: 'assets/images/file.jpg',
        imageUrls: [
          'assets/images/file.jpg',
          'assets/images/file2.jpg',
          'assets/images/file3.jpg'
        ],
        author: 'Fathan',
        likes: [],
        likeCount: 0,
      );
      expect(post.isMultiImage, isTrue);
      expect(post.imageUrls.length, 3);
    });
  });

  group('Widget tests for Home and User pages', () {
    testWidgets('HomePage displays refresh and filter buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(),
        ),
      );
      await tester.pump();

      // Verify Punny title
      expect(find.text('Punny'), findsOneWidget);

      // Verify Refresh Feed button
      expect(find.byTooltip('Refresh Feed'), findsOneWidget);

      // Verify Filter Pins button
      expect(find.byTooltip('Filter & Sort Pins'), findsOneWidget);

      // Verify Quick Filter chips
      expect(find.text('All Pins'), findsWidgets);
      expect(find.text('Popular 🔥'), findsOneWidget);
      expect(find.text('Following ✨'), findsOneWidget);
    });

    testWidgets('UserPage displays tabs for Pins, Saved, Liked, and Following', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserPage(),
          ),
        ),
      );
      await tester.pump();

      // Verify user handle
      expect(find.text('Fathan'), findsOneWidget);

      // Verify the 4 profile tabs
      expect(find.text('Pins'), findsWidgets);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Liked'), findsOneWidget);
      expect(find.text('Following'), findsWidgets);

      // Tap on Saved tab
      await tester.tap(find.text('Saved'));
      await tester.pump();

      // Tap on Following tab
      await tester.tap(find.text('Following').first);
      await tester.pump();
    });
  });

  group('Login & Register form validation tests', () {
    testWidgets('LoginPage blocks sign in when fields are empty or invalid', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );
      await tester.pump();

      // Tap Sign In with empty fields
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      // Verify validation error messages
      expect(find.text('Username is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);

      // Enter too short username and password
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'ab');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), '123');
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Username must be at least 3 characters'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('RegisterPage blocks sign up when fields are empty or invalid', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterPage(),
        ),
      );
      await tester.pump();

      // Ensure button is visible in scrollview and tap with empty fields
      final signUpButton = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(signUpButton);
      await tester.tap(signUpButton);
      await tester.pump();

      // Verify validation errors appear for all required fields
      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);

      // Enter invalid email and mismatched password
      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Alex');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'not-an-email');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'different123');

      await tester.ensureVisible(signUpButton);
      await tester.tap(signUpButton);
      await tester.pump();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });

  group('AddPage Multi-Image & Preview tests', () {
    testWidgets('AddPage renders upload interface with multiple image support', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddPage(),
        ),
      );
      await tester.pump();

      expect(find.text('Create Pin'), findsOneWidget);
      expect(find.text('Upload Images'), findsOneWidget);
      expect(find.text('Add by Image URL'), findsOneWidget);
      expect(find.text('Click to upload pin images'), findsOneWidget);

      // Tap on Add by Image URL tab
      await tester.tap(find.text('Add by Image URL'));
      await tester.pump();

      expect(find.text('Add URL'), findsOneWidget);
    });
  });

  group('PinDetailPage Multi-image Carousel & Comments tests', () {
    testWidgets('PinDetailPage displays carousel controls, love, save, follow, download and comments', (WidgetTester tester) async {
      final multiPost = Post(
        id: 'test-carousel-1',
        title: 'Multi Photo Pin Aesthetic',
        imageUrl: 'assets/images/file.jpg',
        imageUrls: [
          'assets/images/file.jpg',
          'assets/images/file2.jpg',
        ],
        author: 'Sensei',
        likes: ['Yuuka'],
        likeCount: 1,
        description: 'Test carousel pin description',
        category: 'Aesthetic',
        comments: [
          {'user': 'Sensei', 'avatar': 'S', 'text': 'Enjoy the photos!'},
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PinDetailPage(
            post: multiPost,
            onLikeToggle: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pump();

      // Verify title & author
      expect(find.text('Multi Photo Pin Aesthetic'), findsOneWidget);
      expect(find.text('Sensei'), findsWidgets);
      expect(find.text('Test carousel pin description'), findsOneWidget);
      expect(find.text('Aesthetic'), findsOneWidget);

      // Verify carousel multi-image badge
      expect(find.text('1 / 2'), findsOneWidget);

      // Verify Save/Download Image button is present
      expect(find.byTooltip('Save / Download Image'), findsOneWidget);

      // Verify Love and Save buttons
      expect(find.text('Love (1)'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Verify Follow button
      expect(find.text('Follow'), findsWidgets);

      // Tap next image arrow
      final nextArrow = find.byIcon(Icons.arrow_forward_ios);
      expect(nextArrow, findsOneWidget);
      await tester.tap(nextArrow);
      await tester.pump();

      // Badge should update to 2 / 2
      expect(find.text('2 / 2'), findsOneWidget);

      // Add a comment
      await tester.enterText(find.widgetWithText(TextField, 'Add a comment...'), 'Super cool pin!');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      // Comment should be displayed
      expect(find.text('Super cool pin!'), findsOneWidget);
    });
  });
}
