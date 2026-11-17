import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.preferredLanguage = 'en',
  });

  final String id;
  final String email;
  final String displayName;
  final String preferredLanguage;

  factory AppUser.fromSupabaseUser(sb.User user) {
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final email = user.email ?? '';
    final rawName = (meta['display_name'] as String?)?.trim();
    final fallbackName = email.contains('@')
        ? email.split('@').first
        : 'User';
    final lang = (meta['preferred_language'] as String?)?.trim();
    return AppUser(
      id: user.id,
      email: email,
      displayName: (rawName != null && rawName.isNotEmpty)
          ? rawName
          : fallbackName,
      preferredLanguage:
          (lang == 'ur' || lang == 'roman_ur' || lang == 'en') ? lang! : 'en',
    );
  }
}

class SignUpOutcome {
  const SignUpOutcome({
    this.user,
    required this.requiresEmailConfirmation,
  });

  final AppUser? user;
  final bool requiresEmailConfirmation;
}

abstract class AuthService {
  static const defaultSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ctidcjhbjrzqibcynbqo.supabase.co',
  );
  static const defaultSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_3vceBvJK8Pdgd5EHgQKOtA_rVY3O2Yq',
  );

  bool get isConfigured;
  AppUser? get currentUser;
  Stream<AppUser?> get authStateChanges;

  Future<AppUser> signIn({
    required String email,
    required String password,
  });

  Future<SignUpOutcome> signUp({
    required String displayName,
    required String email,
    required String password,
    String preferredLanguage = 'en',
  });

  Future<void> signOut();
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService({sb.SupabaseClient? client})
    : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;

  @override
  bool get isConfigured => true;

  @override
  AppUser? get currentUser {
    final user = _client.auth.currentUser;
    return user == null ? null : AppUser.fromSupabaseUser(user);
  }

  @override
  Stream<AppUser?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((event) {
        final user = event.session?.user;
        return user == null ? null : AppUser.fromSupabaseUser(user);
      });

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure(
          'Sign-in did not return a user session. Please try again.',
        );
      }
      return AppUser.fromSupabaseUser(user);
    } on sb.AuthException catch (error) {
      throw AuthFailure(_readableMessage(error.message));
    } catch (error) {
      if (error is AuthFailure) rethrow;
      throw const AuthFailure(
        'Unable to reach Supabase Auth. Check your connection and try again.',
      );
    }
  }

  @override
  Future<SignUpOutcome> signUp({
    required String displayName,
    required String email,
    required String password,
    String preferredLanguage = 'en',
  }) async {
    try {
      final cleanedName = displayName.trim();
      final cleanedEmail = email.trim();
      final response = await _client.auth.signUp(
        email: cleanedEmail,
        password: password,
        data: {
          'display_name': cleanedName,
          'preferred_language': preferredLanguage,
        },
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure(
          'Registration could not be completed. Please try again.',
        );
      }
      final hasSession = response.session != null;
      if (hasSession) {
        // Best-effort profile upsert when the Postgres trigger isn't installed yet.
        try {
          await _client.from('profiles').upsert({
            'id': user.id,
            'display_name': cleanedName,
            'preferred_language': preferredLanguage,
          });
        } catch (_) {
          // Ignore if RLS or trigger already handled profile creation.
        }
      }
      return SignUpOutcome(
        user: hasSession ? AppUser.fromSupabaseUser(user) : null,
        requiresEmailConfirmation: !hasSession,
      );
    } on sb.AuthException catch (error) {
      throw AuthFailure(_readableMessage(error.message));
    } catch (error) {
      if (error is AuthFailure) rethrow;
      throw const AuthFailure(
        'Unable to reach Supabase Auth. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on sb.AuthException catch (error) {
      throw AuthFailure(_readableMessage(error.message));
    } catch (_) {
      throw const AuthFailure('Could not sign out cleanly. Please try again.');
    }
  }

  String _readableMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Invalid email or password. Please check your credentials.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email address from your inbox before signing in.';
    }
    if (lower.contains('already registered') ||
        lower.contains('user already exists')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (lower.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return raw.isEmpty ? 'Authentication failed. Please try again.' : raw;
  }
}

class UnconfiguredAuthService implements AuthService {
  const UnconfiguredAuthService();

  static const _configMessage =
      'Supabase is not configured. Launch with '
      '--dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...';

  @override
  bool get isConfigured => false;

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> get authStateChanges => const Stream<AppUser?>.empty();

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    throw const AuthFailure(_configMessage);
  }

  @override
  Future<SignUpOutcome> signUp({
    required String displayName,
    required String email,
    required String password,
    String preferredLanguage = 'en',
  }) async {
    throw const AuthFailure(_configMessage);
  }

  @override
  Future<void> signOut() async {}
}
