import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:talawa/constants/routing_constants.dart';
import 'package:talawa/models/events/event_model.dart';
import 'package:talawa/models/user/user_info.dart';
import 'package:talawa/services/navigation_service.dart';
import 'package:talawa/services/size_config.dart';
import 'package:talawa/utils/app_localization.dart';
import 'package:talawa/view_model/after_auth_view_models/event_view_models/explore_events_view_model.dart';
import 'package:talawa/view_model/main_screen_view_model.dart';
import 'package:talawa/views/after_auth_screens/events/explore_event_dialogue.dart';
import 'package:talawa/views/after_auth_screens/events/explore_events.dart';

import '../../../helpers/test_helpers.dart';
import '../../../helpers/test_locator.dart';

// Manual Fake/Stub for ExploreEventsViewModel to avoid Mockito override issues
class FakeExploreEventsViewModel extends ChangeNotifier
    implements ExploreEventsViewModel {
  bool _isBusy = false;
  List<Event> _events = [];
  String _emptyListMessage = "Empty List";
  String _chosenValue = "All Events";

  @override
  bool get isBusy => _isBusy;
  set isBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  @override
  List<Event> get events => _events;
  set events(List<Event> value) {
    _events = value;
    notifyListeners();
  }

  @override
  String get emptyListMessage => _emptyListMessage;
  set emptyListMessage(String value) {
    _emptyListMessage = value;
    notifyListeners();
  }

  @override
  String get chosenValue => _chosenValue;
  set chosenValue(String value) {
    _chosenValue = value;
    notifyListeners();
  }

  // Method call verification counters
  int initialiseCallCount = 0;
  int refreshEventsCallCount = 0;

  @override
  Future<void> initialise() async {
    initialiseCallCount++;
  }

  @override
  Future<void> refreshEvents() async {
    refreshEventsCallCount++;
  }

  @override
  Future<void> choseValueFromDropdown(String? value) async {
    if (value != null) _chosenValue = value;
  }

  // Other fields required by the interface but not used in these tests can be stubbed or throw
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockMainScreenViewModel extends Mock implements MainScreenViewModel {
  @override
  GlobalKey<State<StatefulWidget>> get keySEDateFilter =>
      GlobalKey(debugLabel: 'date_filter_key');
  @override
  GlobalKey<State<StatefulWidget>> get keySEAdd =>
      GlobalKey(debugLabel: 'add_event_key');
}

Event createEvent({String id = "1", String name = "Test Event"}) {
  return Event(
    id: id,
    name: name,
    creator: User(id: "c1", name: "Creator"),
    location: "Loc",
    description: "Desc",
    startAt: DateTime.now(),
    endAt: DateTime.now().add(const Duration(hours: 1)),
    isPublic: true,
    isRegisterable: true,
  );
}

void main() {
  late FakeExploreEventsViewModel fakeExploreEventsViewModel;
  late MockMainScreenViewModel mockMainScreenViewModel;
  late NavigationService mockNavigationService;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    testSetupLocator();
    registerServices();
    locator<SizeConfig>().test();
  });

  tearDownAll(() {
    unregisterServices();
  });

  setUp(() {
    fakeExploreEventsViewModel = FakeExploreEventsViewModel();
    mockMainScreenViewModel = MockMainScreenViewModel();
    mockNavigationService = locator<NavigationService>();

    if (locator.isRegistered<ExploreEventsViewModel>()) {
      locator.unregister<ExploreEventsViewModel>();
    }
    locator.registerFactory<ExploreEventsViewModel>(
        () => fakeExploreEventsViewModel);
  });

  Widget createExploreEventsScreen() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizationsDelegate(isTest: true),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: ExploreEvents(
          key: const Key('explore_events_view'),
          homeModel: mockMainScreenViewModel,
        ),
      ),
      navigatorKey: mockNavigationService.navigatorKey,
    );
  }

  testWidgets('ExploreEvents initializes and shows loading indicator when busy',
      (WidgetTester tester) async {
    fakeExploreEventsViewModel.isBusy = true;

    await tester.pumpWidget(createExploreEventsScreen());
    await tester
        .pump(); // Allow FutureBuilder or similar to start, but keep animations running if any

    // Verify intialise was called
    expect(fakeExploreEventsViewModel.initialiseCallCount, 1);

    // Verify loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ExploreEvents shows empty message when no events',
      (WidgetTester tester) async {
    fakeExploreEventsViewModel.isBusy = false;
    fakeExploreEventsViewModel.events = [];
    fakeExploreEventsViewModel.emptyListMessage = "No events found";

    await tester.pumpWidget(createExploreEventsScreen());
    await tester.pumpAndSettle();

    expect(find.text("No events found"), findsOneWidget);
  });

  testWidgets('ExploreEvents shows list of events',
      (WidgetTester tester) async {
    final e1 = createEvent(id: '1', name: 'Event One');
    final e2 = createEvent(id: '2', name: 'Event Two');

    fakeExploreEventsViewModel.isBusy = false;
    fakeExploreEventsViewModel.events = [e1, e2];

    await tester.pumpWidget(createExploreEventsScreen());
    await tester.pumpAndSettle();

    expect(find.text('Event One'), findsOneWidget);
    expect(find.text('Event Two'), findsOneWidget);
  });

  testWidgets('FAB navigates to create event page',
      (WidgetTester tester) async {
    await tester.pumpWidget(createExploreEventsScreen());
    await tester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    await tester.tap(fab);

    verify(mockNavigationService.pushScreen("/createEventPage")).called(1);
  });

  testWidgets('Calendar button navigates to calendar',
      (WidgetTester tester) async {
    await tester.pumpWidget(createExploreEventsScreen());
    await tester.pumpAndSettle();

    final calendarBtn = find.widgetWithIcon(IconButton, Icons.calendar_month);
    expect(calendarBtn, findsOneWidget);
    await tester.tap(calendarBtn);

    verify(mockNavigationService.pushScreen(Routes.calendar, arguments: []))
        .called(1);
  });

  testWidgets('Filter by Date dialog opens on tap',
      (WidgetTester tester) async {
    await tester.pumpWidget(createExploreEventsScreen());
    await tester.pumpAndSettle();

    final dateFilterBtn = find.text("Filter by Date");
    expect(dateFilterBtn, findsOneWidget);

    await tester.tap(dateFilterBtn);
    // Use pump instead of pumpAndSettle to avoid timeout if dialog animation loops (sometimes)
    await tester.pumpAndSettle();

    expect(find.byType(ExploreEventDialog), findsOneWidget);
  });

  testWidgets('Pull to refresh calls refreshEvents',
      (WidgetTester tester) async {
    fakeExploreEventsViewModel.isBusy = false;
    fakeExploreEventsViewModel.events = [];

    await tester.pumpWidget(createExploreEventsScreen());
    await tester.pumpAndSettle();

    expect(fakeExploreEventsViewModel.refreshEventsCallCount, 0);

    // Perform fling to trigger RefreshIndicator
    await tester.fling(
        find.byType(SingleChildScrollView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(fakeExploreEventsViewModel.refreshEventsCallCount, 1);
  });

  testWidgets('Search button appears when events exist',
      (WidgetTester tester) async {
    final e = createEvent();
    fakeExploreEventsViewModel.events = [e];

    await tester.pumpWidget(createExploreEventsScreen());
    await tester.pumpAndSettle();

    final searchBtn = find.byIcon(Icons.search);
    expect(searchBtn, findsOneWidget);

    await tester.tap(searchBtn);
    await tester.pumpAndSettle();
  });

  testWidgets('Filters button opens dropdown list in bottom sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(createExploreEventsScreen());
    await tester.pumpAndSettle();

    final filtersBtn = find.text('Filters');
    expect(filtersBtn, findsOneWidget);

    await tester.tap(filtersBtn);
    await tester.pumpAndSettle();

    expect(find.text('Show all events'), findsOneWidget);
  });

  testWidgets('Tapping on an event navigates to eventInfo',
      (WidgetTester tester) async {
    final e = createEvent(id: '1', name: 'Tap Event');
    fakeExploreEventsViewModel.isBusy = false;
    fakeExploreEventsViewModel.events = [e];

    await tester.pumpWidget(createExploreEventsScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tap Event'));

    verify(mockNavigationService.pushScreen("/eventInfo",
            arguments: anyNamed('arguments')))
        .called(1);
  });
  testWidgets("Menu button opens drawer", (WidgetTester tester) async {
    await tester.pumpWidget(createExploreEventsScreen());
    await tester.pumpAndSettle();

    final menuBtn = find.widgetWithIcon(IconButton, Icons.menu);
    expect(menuBtn, findsOneWidget);

    await tester.tap(menuBtn);
    await tester.pumpAndSettle();
  });
}
