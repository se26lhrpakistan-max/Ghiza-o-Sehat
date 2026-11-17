import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'api_service.dart';
import 'screens/login_screen.dart';
import 'screens/meal_history_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_service.dart';
import 'services/meal_service.dart';
import 'widgets/curry_disambiguation_card.dart';
import 'widgets/food_search_dialog.dart';
import 'widgets/portion_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AuthService auth = const UnconfiguredAuthService();
  MealService? mealService;
  if (AuthService.defaultSupabaseUrl.isNotEmpty &&
      AuthService.defaultSupabaseAnonKey.isNotEmpty) {
    await sb.Supabase.initialize(
      url: AuthService.defaultSupabaseUrl,
      publishableKey: AuthService.defaultSupabaseAnonKey,
    );
    auth = SupabaseAuthService();
    mealService = SupabaseMealService();
  }
  runApp(MainApp(auth: auth, mealService: mealService));
}

class MainApp extends StatelessWidget {
  const MainApp({
    super.key,
    this.api,
    this.pickPhoto,
    this.auth,
    this.mealService,
  });

  final ApiService? api;
  final Future<XFile?> Function()? pickPhoto;
  final AuthService? auth;
  final MealService? mealService;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ghiza-o-Sehat',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
    home: auth != null
        ? AuthGate(
            auth: auth!,
            api: api,
            pickPhoto: pickPhoto,
            mealService: mealService,
          )
        : MealScreen(
            api: api,
            pickPhoto: pickPhoto,
            mealService: mealService,
          ),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    this.api,
    this.pickPhoto,
    this.mealService,
  });

  final AuthService auth;
  final ApiService? api;
  final Future<XFile?> Function()? pickPhoto;
  final MealService? mealService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AppUser?>? _sub;
  AppUser? _user;
  bool _showRegister = false;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _user = widget.auth.currentUser;
    _sub = widget.auth.authStateChanges.listen((user) {
      if (mounted) {
        setState(() => _user = user);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    await widget.auth.signOut();
    if (mounted) {
      setState(() {
        _user = null;
        _showRegister = false;
        _infoMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user != null) {
      return MealScreen(
        api: widget.api,
        pickPhoto: widget.pickPhoto,
        user: _user,
        onSignOut: _signOut,
        mealService: widget.mealService,
      );
    }
    if (_showRegister) {
      return RegisterScreen(
        auth: widget.auth,
        onRegistered: (outcome) {
          setState(() {
            if (outcome.user != null) {
              _user = outcome.user;
              _showRegister = false;
              _infoMessage = null;
            } else {
              _showRegister = false;
              _infoMessage = outcome.requiresEmailConfirmation
                  ? 'Account created! Check your email to confirm your address, then sign in.'
                  : 'Account created! You can now sign in.';
            }
          });
        },
        onSignInTap: () => setState(() {
          _showRegister = false;
          _infoMessage = null;
        }),
      );
    }
    return LoginScreen(
      auth: widget.auth,
      infoMessage: _infoMessage,
      onSignedIn: (user) => setState(() {
        _user = user;
        _infoMessage = null;
      }),
      onCreateAccountTap: () => setState(() {
        _showRegister = true;
        _infoMessage = null;
      }),
    );
  }
}

class MealScreen extends StatefulWidget {
  const MealScreen({
    super.key,
    this.api,
    this.pickPhoto,
    this.user,
    this.onSignOut,
    this.mealService,
  });

  final ApiService? api;
  final Future<XFile?> Function()? pickPhoto;
  final AppUser? user;
  final Future<void> Function()? onSignOut;
  final MealService? mealService;

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  late final MealService _mealService =
      widget.mealService ?? SupabaseMealService();
  final _weight = TextEditingController();
  List<String> _classes = [];
  Map<String, dynamic>? _prediction;
  Map<String, dynamic>? _result;
  String? _food;
  String? _error;
  String? _photoName;
  Uint8List? _photoBytes;
  bool _confirmed = false;
  bool _busy = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Something went wrong. Please try again or select another photo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadClasses() => _run(() async {
    final foods = await _api.classes();
    if (foods.isEmpty) {
      throw ApiException('No foods were returned. Please retry.');
    }
    if (mounted) setState(() => _classes = foods);
  });

  Future<void> _selectPhoto({ImageSource source = ImageSource.gallery}) =>
      _run(() async {
        final photo = await (widget.pickPhoto?.call() ??
            ImagePicker().pickImage(source: source));
        if (photo == null || !mounted) return;
        final bytes = await photo.readAsBytes();
        setState(() {
          _photoName = photo.name;
          _photoBytes = bytes;
          _prediction = null;
          _result = null;
          _food = null;
          _confirmed = false;
          _saved = false;
          _weight.clear();
        });
        final prediction = await _api.predict(photo);
        if (!mounted) return;
        setState(() {
          _prediction = prediction;
          final predictedFood = prediction['prediction'] as String;
          _food = _classes.contains(predictedFood) ? predictedFood : null;
          _confirmed = false;
          _saved = false;
        });
      });

  void _changeFood(String? food) => setState(() {
    _food = food;
    _confirmed = false;
    _result = null;
    _error = null;
    _saved = false;
  });

  Future<void> _estimate() async {
    final grams = double.tryParse(_weight.text.trim());
    if (grams == null || !grams.isFinite || grams <= 0) {
      setState(() => _error = 'Enter a positive weight in grams, such as 50.');
      return;
    }
    if (!_confirmed || _food == null) return;
    await _run(() async {
      setState(() {
        _result = null;
        _saved = false;
      });
      final result = await _api.estimate(_food!, grams);
      if (mounted) setState(() => _result = result);
    });
  }

  Future<void> _saveMeal() async {
    if (_result == null || _food == null || widget.user == null) return;
    final grams = double.tryParse(_weight.text.trim());
    if (grams == null || grams <= 0) return;

    await _run(() async {
      await _mealService.saveMeal(
        userId: widget.user!.id,
        confirmedFood: _food!,
        portionGrams: grams,
        calories: (_result!['calories'] as num).toDouble(),
        predictedClass: _prediction?['prediction'] as String?,
        predictionConfidence:
            (_prediction?['confidence'] as num?)?.toDouble(),
        top3: _prediction?['top3'] as List<dynamic>?,
      );
      if (mounted) {
        setState(() => _saved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal saved to history!')),
        );
      }
    });
  }

  @override
  void dispose() {
    _weight.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  String _label(String food) => food.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ghiza-o-Sehat'),
      actions: [
        if (widget.user != null) ...[
          IconButton(
            key: const Key('mealHistoryButton'),
            tooltip: 'Meal history',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MealHistoryScreen(
                    mealService: _mealService,
                    userId: widget.user!.id,
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Text(
                widget.user!.displayName,
                key: const Key('signedInUserName'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
        if (widget.onSignOut != null)
          IconButton(
            key: const Key('signOutButton'),
            tooltip: 'Sign out',
            onPressed: _busy ? null : widget.onSignOut,
            icon: const Icon(Icons.logout),
          ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Understand your meal',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a photo, confirm the food, then enter its cooked weight in grams.',
          ),
          const SizedBox(height: 16),
          if (_busy) ...[
            const LinearProgressIndicator(),
            const Text('Please wait…'),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            Text(
              _error!,
              key: const Key('error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          if (_classes.isEmpty)
            OutlinedButton(
              onPressed: _busy ? null : _loadClasses,
              child: const Text('Retry connection'),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('selectPhoto'),
                  onPressed: _busy || _classes.isEmpty
                      ? null
                      : () => _selectPhoto(source: ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Select food photograph'),
                ),
              ),
              if (widget.pickPhoto == null) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Take photo with camera',
                  onPressed: _busy || _classes.isEmpty
                      ? null
                      : () => _selectPhoto(source: ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                ),
              ],
            ],
          ),
          if (_photoName != null) ...[
            const SizedBox(height: 8),
            Text('Photo: $_photoName'),
          ],
          if (_photoBytes != null && _photoBytes!.length > 100) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _photoBytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (_prediction != null) ...[
            const SizedBox(height: 20),
            Text(
              'Prediction: ${_label(_prediction!['prediction'] as String)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text('Model suggestions — please check them yourself.'),
            for (final candidate in _prediction!['top3'] as List)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_label(candidate['class'] as String)),
                subtitle: Text(
                  '${(candidate['confidence'] as num).toStringAsFixed(1)}% model confidence',
                ),
                trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _changeFood(candidate['class'] as String),
                  child: const Text('Choose'),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_food),
                    initialValue: _classes.contains(_food) ? _food : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Choose or correct the food',
                    ),
                    items: _classes
                        .map(
                          (food) => DropdownMenuItem(
                            value: food,
                            child: Text(_label(food)),
                          ),
                        )
                        .toList(),
                    onChanged: _busy ? null : _changeFood,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Search food list',
                  icon: const Icon(Icons.search),
                  onPressed: _busy || _classes.isEmpty
                      ? null
                      : () async {
                          final selected = await FoodSearchDialog.show(
                            context,
                            classes: _classes,
                            selected: _food,
                          );
                          if (selected != null && mounted) {
                            _changeFood(selected);
                          }
                        },
                ),
              ],
            ),
            if (_food == 'creamy_chicken_curry')
              CurryDisambiguationCard(
                onSelectDish: (dish) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Specific dish selected: ${_label(dish)}. Note: Verified nutrition data is currently available for chapati only.',
                      ),
                    ),
                  );
                },
                onSearchOther: () async {
                  final selected = await FoodSearchDialog.show(
                    context,
                    classes: _classes,
                    selected: _food,
                  );
                  if (selected != null && mounted) {
                    _changeFood(selected);
                  }
                },
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I confirm this is the food I ate'),
              value: _confirmed,
              onChanged: _busy || _food == null
                  ? null
                  : (value) => setState(() {
                      _confirmed = value ?? false;
                      _result = null;
                      _saved = false;
                    }),
            ),
            if (_confirmed && _food != null)
              PortionGuideWidget(
                food: _food!,
                currentGrams: double.tryParse(_weight.text),
                onSelectGrams: (grams) {
                  setState(() {
                    _weight.text = grams.toStringAsFixed(0);
                    _result = null;
                    _error = null;
                    _saved = false;
                  });
                },
              ),
            TextField(
              controller: _weight,
              enabled: !_busy && _confirmed,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Cooked food weight (grams)',
                hintText: '50',
              ),
              onChanged: (_) => setState(() {
                _result = null;
                _error = null;
                _saved = false;
              }),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only chapati currently has nutrition data. Weight must come from you, not the photograph.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || !_confirmed ? null : _estimate,
              child: const Text('Estimate calories'),
            ),
          ],
          if (_result != null) ...[
            const Divider(height: 32),
            if (_result!['status'] == 'unavailable') ...[
              Text(
                'Nutrition data unavailable',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(_result!['reason'] as String),
            ] else ...[
              Text(
                'Estimated calories: ${_result!['calories']} kcal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${_label(_result!['confirmed_food'] as String)} · ${_result!['portion_grams']} g',
              ),
              Text('${_result!['kcal_per_100g']} kcal per 100 g'),
              const SizedBox(height: 8),
              Text(_result!['source_name'] as String),
              SelectableText(_result!['source_reference'] as String),
              for (final note in _result!['notes'] as List)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(note as String),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('saveMealButton'),
                onPressed: _busy || _saved || widget.user == null
                    ? null
                    : _saveMeal,
                icon: Icon(_saved ? Icons.check : Icons.bookmark_add_outlined),
                label: Text(
                  widget.user == null
                      ? 'Sign in to save meal'
                      : _saved
                          ? 'Saved to meal log'
                          : 'Save meal to log',
                ),
              ),
            ],
          ],
        ],
      ),
    ),
  );
}
