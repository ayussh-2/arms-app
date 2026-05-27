# ARMS Flutter App — Optimization & Memory Audit

> Full codebase audit covering **performance**, **memory**, **architecture**, and **code quality**. Each finding includes severity, location, and a concrete fix.

---

## Executive Summary

| Category | Critical | High | Medium | Low |
|---|---|---|---|---|
| Memory & Leaks | 1 | 3 | 2 | 1 |
| Rendering Performance | 0 | 4 | 3 | 2 |
| Architecture & State | 0 | 2 | 3 | 1 |
| Network / GraphQL | 0 | 2 | 2 | 0 |
| Code Quality | 0 | 1 | 4 | 3 |

**Total: 34 findings** — 1 critical, 12 high, 14 medium, 7 low.

---

## 1. Memory & Leak Issues

### 🔴 CRITICAL — `MarkEntryScreen`: Unbounded TextEditingController Allocation

**File:** [mark_entry_screen.dart](file:///d:/Projects/arms/arms/lib/screens/exams/mark_entry_screen.dart#L98-L123)

For every student × subject combination, a `TextEditingController` is created and each one adds a listener. With 60 students and 4 subjects, that's **240 controllers + 240 listeners** simultaneously alive.

**Problem:** Controllers are stored in a nested `Map<String, Map<String, TextEditingController>>` but the `_onMarkChanged` callback creates a *new* `Timer` on every keystroke from **any** controller. Since all 240 controllers share the same listener method, a single character typed cancels and recreates the timer — the architecture is sound, but the sheer volume of controllers and listeners is the real issue.

**Fix:**
```dart
// Option A: Use a single ValueNotifier<String> per cell instead of TextEditingController
// Option B: Lazily create controllers only for visible cards
// Option C: Use a data-only model and only 2 shared controllers for the focused cell

// Recommended: ListView.builder already lazily builds cards, but controllers
// persist for ALL students. Move to a model-based approach:

class StudentMarkData {
  String marks;
  bool isAbsent;
  String status;
  StudentMarkData({this.marks = '', this.isAbsent = false, this.status = 'NORMAL'});
}

// Store: Map<String, Map<String, StudentMarkData>> _markData = {};
// Only create a TextEditingController when a cell is focused, and write
// back to the model on unfocus. This reduces 240 controllers to ~2-4.
```

---

### 🟠 HIGH — `_autoSaveTimer` never fires save to backend

**File:** [mark_entry_screen.dart](file:///d:/Projects/arms/arms/lib/screens/exams/mark_entry_screen.dart#L132-L144)

The timer only updates a UI label (`_isDraftSaved`) but never persists data. If the user kills the app after seeing "Draft saved", data is lost. This is a UX trust issue.

**Fix:** Either rename the label to "Changes pending" or implement actual draft persistence (e.g., write to Hive local storage on each timer fire).

---

### 🟠 HIGH — `InMemoryStore` GraphQL cache grows unbounded

**File:** [graphql_client.dart](file:///d:/Projects/arms/arms/lib/core/graphql/graphql_client.dart)

The `GraphQLClient` uses `InMemoryStore` with no eviction strategy. Over a long session (teacher marking attendance for 10+ classes), the cache accumulates large response payloads.

**Fix:**
```dart
// Add periodic cache clearing after navigation
// Or use HiveStore with size limits:
static Future<GraphQLClient> _buildClient(String url) async {
  await initHiveForFlutter();
  final store = HiveStore();
  // ...
}
```

---

### 🟠 HIGH — `DebugOverlay` Stack wraps entire widget tree

**File:** [debug_overlay.dart](file:///d:/Projects/arms/arms/lib/widgets/debug_overlay.dart#L47-L129)

The `DebugOverlay` wraps the entire app in a `Stack` and conditionally renders a full-screen `Container` with `BackdropFilter`-equivalent opacity. Even when `_showPanel == false`, the `Stack` adds an extra layer to the render tree for every frame.

**Fix:** Use `Overlay` entries or make the debug button a simple `FloatingActionButton` positioned via `Positioned` only when in debug mode. Gate the entire widget behind `kDebugMode`:
```dart
if (kDebugMode) return DebugOverlay(child: child);
return child;
```

---

### 🟡 MEDIUM — `LeaveApplyScreen` retains `_allStudents` list after navigation

**File:** [leave_apply_screen.dart](file:///d:/Projects/arms/arms/lib/screens/attendance/leave_apply_screen.dart#L39-L41)

The screen loads all students into `_allStudents` and `_filteredStudents`. These are not cleared on pop, relying on GC. Since `image_url` strings are included, this is a moderate memory footprint for large schools.

**Fix:** Acceptable as-is since `StatefulWidget.dispose()` will release, but consider fetching with pagination or debounced search-as-you-type from the server.

---

### 🟡 MEDIUM — `ExamListScreen` computed getters recompute on every build

**File:** [exam_list_screen.dart](file:///d:/Projects/arms/arms/lib/screens/exams/exam_list_screen.dart#L70-L112)

Five getters (`uniqueSeries`, `uniqueSubjects`, `uniqueSchools`, `uniqueClasses`, `uniqueSections`) iterate + allocate Sets + Lists on every call. They're invoked multiple times per build (in filter pills).

**Fix:** Cache these as instance variables, recomputed only when `_allExams` changes:
```dart
List<String> _cachedSeries = [];

void _recomputeFilterOptions() {
  _cachedSeries = _allExams.map((e) => e['series']?['name'] as String?)
    .whereType<String>().toSet().toList();
  // ... repeat for others
}
```

---

### 🟢 LOW — `AppTextStyles` getters call `GoogleFonts.plusJakartaSans()` on every access

**File:** [app_text_styles.dart](file:///d:/Projects/arms/arms/lib/core/theme/app_text_styles.dart#L10-L49)

Each `get` creates a new `TextStyle` object. While Google Fonts internally caches the font, the `TextStyle` wrapper allocations are unnecessary.

**Fix:** Use `static final` instead of `static get`:
```dart
static final TextStyle displayLarge = GoogleFonts.plusJakartaSans(
  fontSize: 32, fontWeight: FontWeight.w700, ...
);
```

---

## 2. Rendering Performance

### 🟠 HIGH — `ExamViewScreen` uses spread `List.generate` instead of `SliverList`

**File:** [exam_view_screen.dart](file:///d:/Projects/arms/arms/lib/screens/exams/exam_view_screen.dart#L307)

```dart
...List.generate(_filteredMarks.length, (i) => _buildMarkRow(i, _filteredMarks[i], totalMarks)),
```

This eagerly builds **all** mark rows. For exams with 200+ students, this creates 200+ widgets at once inside a `ListView`.

**Fix:** Move to `ListView.builder` or `SliverList` with `SliverChildBuilderDelegate` (which the `ExamListScreen` already uses correctly):
```dart
// Replace ListView with CustomScrollView + SliverList
SliverList(
  delegate: SliverChildBuilderDelegate(
    (_, i) => _buildMarkRow(i, _filteredMarks[i], totalMarks),
    childCount: _filteredMarks.length,
  ),
),
```

---

### 🟠 HIGH — `AttendanceFeedScreen` uses `List.generate` with spread

**File:** [attendance_feed_screen.dart](file:///d:/Projects/arms/arms/lib/screens/attendance/attendance_feed_screen.dart)

Same pattern as above — the student roster is rendered with `...List.generate()` inside a `SingleChildScrollView` or similar. This eagerly creates all student row widgets.

**Fix:** Replace with `ListView.builder` wrapping `ArmsStudentRow` widgets. The builder pattern only creates widgets currently visible on screen + a small buffer.

---

### 🟠 HIGH — `withOpacity()` called extensively throughout

**Files:** Multiple (21+ occurrences across the codebase)

`Color.withOpacity()` creates a **new Color object** on every call during build. When used inside `BoxDecoration`, `Border.all`, etc., these are recreated on every rebuild.

**Occurrences (sample):**
- [exam_list_screen.dart:319](file:///d:/Projects/arms/arms/lib/screens/exams/exam_list_screen.dart#L319) — `AppColors.outline.withOpacity(0.3)`
- [exam_list_screen.dart:351](file:///d:/Projects/arms/arms/lib/screens/exams/exam_list_screen.dart#L351) — `AppColors.outline.withOpacity(0.15)`
- [mark_entry_screen.dart:539](file:///d:/Projects/arms/arms/lib/screens/exams/mark_entry_screen.dart#L539) — repeated 8+ times

**Fix:** Pre-compute as `static const` in `AppColors`:
```dart
class AppColors {
  // Add pre-computed opacity variants
  static const Color outlineLight = Color(0x26C4C7C7);  // 0.15 opacity
  static const Color outlineMediumLight = Color(0x4DC4C7C7); // 0.3 opacity
}
```

---

### 🟠 HIGH — `MarkEntryScreen` `GridView.builder` inside `ListView.builder`

**File:** [mark_entry_screen.dart](file:///d:/Projects/arms/arms/lib/screens/exams/mark_entry_screen.dart#L523-L564)

Each student card contains a `GridView.builder` with `shrinkWrap: true` and `NeverScrollableScrollPhysics`. While this works, `shrinkWrap: true` forces the grid to compute its full size eagerly, defeating lazy rendering.

**Fix:** Since subject count is typically small (2-6), replace `GridView.builder` with a simple `Wrap` or `Row` with explicit `Column` children. This avoids the overhead of a scroll physics calculation:
```dart
Wrap(
  spacing: 12, runSpacing: 12,
  children: _subjects.map((es) => SizedBox(
    width: (MediaQuery.of(context).size.width - 80) / 2,
    child: _buildSubjectInput(sid, es, isAbsent),
  )).toList(),
),
```

---

### 🟡 MEDIUM — `AnimatedContainer` used for non-animated state changes

**Files:** Multiple locations
- [arms_student_row.dart:121](file:///d:/Projects/arms/arms/lib/widgets/arms_student_row.dart#L121) — P/A button toggle
- [attendance_config_screen.dart:240](file:///d:/Projects/arms/arms/lib/screens/attendance/attendance_config_screen.dart#L240) — Session chips
- [mark_entry_screen.dart:481](file:///d:/Projects/arms/arms/lib/screens/exams/mark_entry_screen.dart#L481)

`AnimatedContainer` maintains an internal `AnimationController` even for simple color switches. If the animation duration is very short (150ms), the overhead may not justify the effect.

**Impact:** Low per-widget, but multiplied by roster size (60 students × 2 buttons = 120 animation controllers).

**Fix:** Use `Container` with explicit `TweenAnimationBuilder` only where the animation is actually visible, or keep `AnimatedContainer` but ensure the parent widget doesn't rebuild unnecessarily.

---

### 🟡 MEDIUM — `SingleChildScrollView` used where `CustomScrollView` is more appropriate

**File:** [attendance_config_screen.dart](file:///d:/Projects/arms/arms/lib/screens/attendance/attendance_config_screen.dart#L155)

The attendance config screen wraps its entire body in `SingleChildScrollView`, which builds all children eagerly. The content is short enough that this is acceptable, but the `LeaveManagementWidget` embedded via tab index renders a `Query` widget that can return long lists.

**Fix:** Consider using `CustomScrollView` with `SliverToBoxAdapter` for fixed content and `SliverList` for dynamic leave lists.

---

### 🟡 MEDIUM — `copyWith()` called excessively on `TextStyle`

**Files:** Throughout entire codebase (50+ occurrences)

Almost every `Text` widget calls `.copyWith(fontWeight: ..., color: ...)` on a pre-defined style. Each call allocates a new `TextStyle`.

**Fix:** Define complete styles in `AppTextStyles` to minimize `copyWith` calls:
```dart
static final TextStyle headerSmallBold = GoogleFonts.plusJakartaSans(
  fontSize: 18, fontWeight: FontWeight.w700,
  letterSpacing: -0.18, color: AppColors.textMain,
);
```

---

### 🟢 LOW — `IndexedStack` in `ShellScreen` keeps all 3 tabs alive

**File:** [shell_screen.dart](file:///d:/Projects/arms/arms/lib/screens/shell_screen.dart#L34-L43)

`IndexedStack` preserves state of all children, meaning `ExamListScreen`, `AttendanceConfigScreen`, and `DashboardScreen` all remain in memory even when not visible.

**Impact:** Low for 3 tabs, but means GraphQL queries and controllers from inactive tabs persist. This is a deliberate tradeoff for preserving scroll position.

**Fix (optional):** If memory is tight, switch to lazy tab loading:
```dart
body: [DashboardScreen(...), AttendanceConfigScreen(), ExamListScreen()][_currentIndex],
```

---

### 🟢 LOW — Missing `const` constructors in leaf widgets

Several private widgets could benefit from `const` constructors to enable compile-time const folding:
- `_MetaItem` in exam_list_screen.dart
- `_ConfigRow` in mark_entry_screen.dart  
- `_HeaderMeta` in exam_view_screen.dart

---

## 3. Architecture & State Management

### 🟠 HIGH — No separation between UI and data layers

**All screens** directly call `GraphQLProvider.of(context).value.query()` inside `StatefulWidget` methods. This tightly couples the UI to the network layer.

**Impact:**
- Cannot unit test business logic without mocking the entire widget tree
- Duplicate query calls when the same data is needed in multiple screens
- No single source of truth for entities (exams, students, marks)

**Fix:** Introduce a repository pattern:
```
lib/
  data/
    repositories/
      exam_repository.dart
      attendance_repository.dart
      student_repository.dart
    models/
      exam.dart
      student.dart
      mark.dart
```

```dart
class ExamRepository {
  final GraphQLClient _client;
  ExamRepository(this._client);
  
  Future<List<Exam>> getExams({String? seriesId}) async {
    final result = await _client.query(...);
    return (result.data?['exams'] as List)
      .map((e) => Exam.fromJson(e)).toList();
  }
}
```

---

### 🟠 HIGH — Raw `Map<String, dynamic>` used everywhere instead of typed models

**All screens** work with `Map<String, dynamic>` for exams, students, marks, and leaves. This leads to:
- Runtime errors from typos in key names (e.g., `exam['seires']` fails silently)
- No IDE autocompletion
- Repeated null-checking and casting

**Fix:** Create Dart model classes with `fromJson` factories:
```dart
class Exam {
  final String id;
  final String name;
  final String examDate;
  final int totalMarks;
  final bool markSaved;
  final ExamSeries? series;
  final List<ExamSubject> subjects;
  
  Exam.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['name'] as String? ?? '',
      // ...
}
```

---

### 🟡 MEDIUM — Duplicated `_parseMeta()` / `parseMeta()` logic

**Files:**
- [exam_list_screen.dart:776-793](file:///d:/Projects/arms/arms/lib/screens/exams/exam_list_screen.dart#L776-L793) (in `_ExamCard`)
- [exam_view_screen.dart:80-97](file:///d:/Projects/arms/arms/lib/screens/exams/exam_view_screen.dart#L80-L97) (in `_ExamViewScreenState`)

Identical UUID-detection and display logic duplicated across screens.

**Fix:** Extract to a shared utility:
```dart
// lib/core/utils/display_helpers.dart
String formatMetaField(dynamic val, String type) { ... }
```

---

### 🟡 MEDIUM — Duplicated bottom sheet patterns

Almost every screen implements its own `showModalBottomSheet` with the same drag handle, rounded corners, and padding. There are **7+ nearly identical implementations**.

**Fix:** Create a shared `ArmsBottomSheet` wrapper:
```dart
Future<T?> showArmsBottomSheet<T>(BuildContext context, {
  required String title,
  required WidgetBuilder bodyBuilder,
}) { ... }
```

---

### 🟡 MEDIUM — Navigation uses string-based routes

**File:** [main.dart](file:///d:/Projects/arms/arms/lib/main.dart)

Routes like `'/attendance-feed'`, `'/mark-entry'`, etc. are string literals scattered across screens. Typos won't be caught at compile time.

**Fix:** Use a centralized route constants class or switch to a typed routing solution:
```dart
class AppRoutes {
  static const attendanceFeed = '/attendance-feed';
  static const markEntry = '/mark-entry';
  static const examView = '/exam-view';
  // ...
}
```

---

### 🟢 LOW — `ArmsTopAppBar` has tight coupling to `ShellScreenState`

**File:** [arms_top_app_bar.dart:40](file:///d:/Projects/arms/arms/lib/widgets/arms_top_app_bar.dart#L40)

```dart
context.findAncestorStateOfType<ShellScreenState>()?.switchTab(0);
```

This creates a hard dependency from a generic widget to a specific screen's state. It will silently do nothing if the widget tree changes.

**Fix:** Use a callback or a navigation service instead.

---

## 4. Network / GraphQL Issues

### 🟠 HIGH — No error handling for GraphQL exceptions in most screens

**Files:**
- [exam_list_screen.dart:52-67](file:///d:/Projects/arms/arms/lib/screens/exams/exam_list_screen.dart#L52-L67) — `_loadExams` has no error handling
- [exam_view_screen.dart:50-63](file:///d:/Projects/arms/arms/lib/screens/exams/exam_view_screen.dart#L50-L63) — `_loadMarks` has no error handling
- [mark_entry_screen.dart:60-130](file:///d:/Projects/arms/arms/lib/screens/exams/mark_entry_screen.dart#L60-L130) — `_loadData` has no error handling

If the network fails, these screens silently show empty data or get stuck on the loading spinner.

**Fix:** Add try-catch blocks and display error states:
```dart
Future<void> _loadExams() async {
  try {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(...);
    if (result.hasException) {
      _showErrorSnackbar(result.exception.toString());
      return;
    }
    // ... success path
  } catch (e) {
    if (mounted) _showErrorSnackbar('Connection error: $e');
  }
}
```

---

### 🟠 HIGH — `AttendanceConfigScreen._showClassPicker` makes 2 sequential queries

**File:** [attendance_config_screen.dart:65-83](file:///d:/Projects/arms/arms/lib/screens/attendance/attendance_config_screen.dart#L65-L83)

Two separate `await client.query()` calls are made sequentially — first for classes, then for sections. These are independent and should be parallelized.

**Fix:**
```dart
final results = await Future.wait([
  client.query(QueryOptions(document: gql(GqlQueries.getClasses))),
  client.query(QueryOptions(document: gql(GqlQueries.getSections))),
]);
final classes = results[0].data?['classes'] as List? ?? [];
final sections = results[1].data?['sections'] as List? ?? [];
```

---

### 🟡 MEDIUM — `FetchPolicy.networkOnly` used in `ExamListScreen` prevents caching

**File:** [exam_list_screen.dart:58](file:///d:/Projects/arms/arms/lib/screens/exams/exam_list_screen.dart#L58)

Every load of the exam list forces a network request, even if the data was just fetched. For frequently visited tabs (via `IndexedStack`), this wastes bandwidth.

**Fix:** Use `FetchPolicy.cacheAndNetwork` to show cached data immediately while refreshing in the background.

---

### 🟡 MEDIUM — `MarkEntryScreen` makes 2 sequential queries during `_loadData`

**File:** [mark_entry_screen.dart:71-83](file:///d:/Projects/arms/arms/lib/screens/exams/mark_entry_screen.dart#L71-L83)

Students and marks are fetched sequentially.

**Fix:** Use `Future.wait` as shown above.

---

## 5. Code Quality

### 🟠 HIGH — `ExamListScreen` is 1010 lines in a single file

**File:** [exam_list_screen.dart](file:///d:/Projects/arms/arms/lib/screens/exams/exam_list_screen.dart)

This file contains the screen state, 5 filter getters, filter logic, action sheet, filter options sheet, report tab with stat cards, progress bars, and report items, plus 3 private widget classes.

**Fix:** Split into:
- `exam_list_screen.dart` — Screen + state (~300 lines)
- `exam_card.dart` — `_ExamCard` widget
- `exam_reports_tab.dart` — Reports sub-tab content
- `exam_filter_sheet.dart` — Filter bottom sheet logic

---

### 🟡 MEDIUM — `leave_apply_screen.dart` is 788 lines

Similar to above — form logic, student search, attachment handling, and date picking are all in one file.

---

### 🟡 MEDIUM — Hardcoded mock data in `ExamCreateScreen`

**File:** [exam_create_screen.dart:27-59](file:///d:/Projects/arms/arms/lib/screens/exams/exam_create_screen.dart#L27-L59)

Series, schools, classes, and subjects are hardcoded lists. These should come from GraphQL queries or be clearly marked as `// TODO: Fetch from API`.

---

### 🟡 MEDIUM — `ExamCreateScreen._handleCreate` uses `Future.delayed` for fake spinner

**File:** [exam_create_screen.dart:199](file:///d:/Projects/arms/arms/lib/screens/exams/exam_create_screen.dart#L199)

```dart
await Future.delayed(const Duration(milliseconds: 1500));
```

This simulates network latency. Should be replaced with an actual GraphQL mutation.

---

### 🟡 MEDIUM — Reports tab uses hardcoded statistics

**File:** [exam_list_screen.dart:675-738](file:///d:/Projects/arms/arms/lib/screens/exams/exam_list_screen.dart#L675-L738)

Values like `'76.4%'`, `'98.0%'`, `'95.8%'` are hardcoded strings. These should be computed from actual exam data or fetched from a dedicated API.

---

### 🟢 LOW — Inconsistent `dispose()` practices

Some screens properly dispose controllers while others don't have explicit dispose for all resources:
- `ExamListScreen` disposes `_searchController` ✅
- `ExamViewScreen` disposes `_searchCtrl` ✅
- `MarkEntryScreen` disposes `_autoSaveTimer` and all controllers ✅
- `ExportSheetWidget` — not checked but likely manages its own controllers

---

### 🟢 LOW — No loading skeleton / shimmer effects

All screens show a plain `CircularProgressIndicator` during loading. Modern apps use shimmer placeholders that match the layout structure.

---

### 🟢 LOW — Deprecated API: `withOpacity` should become `withValues`

**Note:** Flutter 3.27+ deprecated `Color.withOpacity()` in favor of `Color.withValues(alpha: ...)`. The codebase inconsistently uses both (e.g., `ArmsStickyFooter` uses `withValues` but most others use `withOpacity`).

---

## Prioritized Action Plan

### Phase 1 — Quick Wins (1-2 days)
| # | Action | Impact |
|---|---|---|
| 1 | Replace `List.generate` spreads with `ListView.builder` / `SliverList` in ExamView + AttendanceFeed | 🔴 High perf improvement |
| 2 | Pre-compute `withOpacity` colors as `static const` in `AppColors` | 🟠 Reduces widget allocations |
| 3 | Change `static get` to `static final` in `AppTextStyles` | 🟡 Minor GC reduction |
| 4 | Parallelize `Future.wait` for sequential GraphQL queries | 🟠 Faster screen loads |
| 5 | Add error handling to all `_load*` methods | 🟠 UX reliability |

### Phase 2 — Structural Improvements (3-5 days)
| # | Action | Impact |
|---|---|---|
| 6 | Create typed model classes for Exam, Student, Mark, Leave | 🟠 Type safety + IDE support |
| 7 | Extract shared `ArmsBottomSheet` utility | 🟡 Code deduplication |
| 8 | Cache filter options in `ExamListScreen` | 🟡 Fewer allocations |
| 9 | Replace `GridView.builder(shrinkWrap)` with `Wrap` in MarkEntry | 🟠 Better perf |
| 10 | Split 1000+ line files into focused modules | 🟡 Maintainability |

### Phase 3 — Architecture Refactor (1-2 weeks)
| # | Action | Impact |
|---|---|---|
| 11 | Introduce Repository pattern for data access | 🟠 Testability + separation |
| 12 | Move `MarkEntryScreen` to model-based mark tracking (eliminate 240 controllers) | 🔴 Memory critical |
| 13 | Add `HiveStore` for GraphQL cache with eviction | 🟠 Long-session stability |
| 14 | Gate `DebugOverlay` behind `kDebugMode` | 🟡 Prod perf |
| 15 | Add route constants class | 🟡 Compile-time safety |

---

> [!TIP]
> **Start with Phase 1** — these are low-risk, high-reward changes that can be implemented without changing the app's architecture. Phase 2 and 3 require more planning but pay off significantly for long-term maintainability.
