# Reusable Flutter Components: ARMS App

This document outlines the list of reusable widgets, layout patterns, and visual foundations for the ARMS (Attendance & Resource Management System) Flutter application, aligning with the **"Clean Utility"** design language of the design specification.

---

## 1. Foundation: Theme & Visual Tokens

A consistent foundation ensures all custom widgets look and behave identically across screens. In Flutter, map the CSS Tailwind properties to a cohesive `ThemeData`.

### 1.1 Color Palette (`AppColors`)
Create a static class `AppColors` representing the project's brand and semantic values:
```dart
import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0051D5);        // ARMS Blue (Primary actions)
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFFFFFFF);     // Pure White surface
  static const Color cardSurface = Color(0xFFF5F5F5);    // Light contrasting gray
  static const Color textMain = Color(0xFF0D0D0D);       // Sleek dark gray for main copy
  static const Color textSecondary = Color(0xFF8A8A8A);  // Muted gray for subtitles/meta
  static const Color outline = Color(0xFFC4C7C7);        // Border outlines
  
  // Semantic Colors
  static const Color successBg = Color(0xFFDCFCE7);      // Pale green
  static const Color successText = Color(0xFF16A34A);    // Dark green
  static const Color errorBg = Color(0xFFFEE2E2);        // Pale red
  static const Color errorText = Color(0xFFDC2626);      // Vibrant red
}
```

### 1.2 Corner Radii (`AppBorderRadius`)
Define the standard corner radii specified in the brief:
```dart
import 'package:flutter/material.dart';

class AppBorderRadius {
  static final BorderRadius roundEight = BorderRadius.circular(8.0);
  static final BorderRadius roundTwelve = BorderRadius.circular(12.0);
  static final BorderRadius roundSixteen = BorderRadius.circular(16.0);
  static final BorderRadius roundFull = BorderRadius.circular(9999.0);
}
```

### 1.3 Typography (`AppTextStyles`)
Define text styles using `Plus Jakarta Sans`:
```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -1.28,
    color: AppColors.textMain,
  );

  static const TextStyle displayMobile = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -1.12,
    color: AppColors.textMain,
  );

  static const TextStyle headerSmall = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 18,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.18,
    color: AppColors.textMain,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textMain,
  );

  static const TextStyle labelXs = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelXsUppercase = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.6,
    color: AppColors.textSecondary,
  );
}
```

---

## 2. Shared/Common Navigation Components

### 2.1 `ArmsBottomNavBar`
**Usage:** Bottom navigation bar on mobile interfaces with Truecaller-style right-aligned profile icon.
- **Attributes:**
  - `currentIndex` (int)
  - `onTap` (Function(int))
  - `showProfile` (bool)
- **Visuals:** Pure White, flat, thin top border (`#F0F0F0`), custom icon/label alignments with secondary color scaling indicator.

### 2.2 `ArmsTopAppBar`
**Usage:** Consistent app header with a back action, title, history icon, and right-aligned circular profile avatar.
- **Attributes:**
  - `title` (String)
  - `showBackButton` (bool)
  - `actions` (List<Widget>)
- **Visuals:** Height: 56px, background: `AppColors.background`, no elevation, thin boundary border.

### 2.3 `ArmsSidebarNav` (Desktop Specific)
**Usage:** Fixed navigation panel for screen sizes over 768dp.
- **Attributes:**
  - `currentIndex` (int)
  - `onDestinationSelected` (Function(int))

---

## 3. Interactive Inputs & Selector Components

### 3.1 `ArmsInputField`
**Usage:** Rounded-full form inputs used for user authentication and searches.
- **Attributes:**
  - `controller` (TextEditingController)
  - `hintText` (String)
  - `prefixIcon` (IconData)
  - `obscureText` (bool)
  - `suffixIcon` (Widget?)
- **Visuals:** Full-pill shape, background filled with `AppColors.cardSurface`, focus borders highlighting in `AppColors.primary` (No hard borders in passive state).

### 3.2 `ArmsDropdownSelector`
**Usage:** Large picker block fields (e.g., Session selection, Class/Section selection).
- **Attributes:**
  - `label` (String)
  - `value` (String)
  - `icon` (IconData)
  - `onTap` (VoidCallback)
- **Visuals:** Rounded-pill shape, height: 56dp, background: `AppColors.cardSurface`, trailing dropdown chevron.

### 3.3 `ArmsSegmentedControl`
**Usage:** Sub-navigation pills showing options like Feed, Leave, and Sheet.
- **Attributes:**
  - `options` (List<String>)
  - `selectedIndex` (int)
  - `onChanged` (Function(int))
- **Visuals:** Fully rounded container with `AppColors.cardSurface` background. Active item slides gracefully with a soft drop-shadow and white bubble background.

### 3.4 `ArmsToggleButton`
**Usage:** iOS/Material-style binary switch (e.g., Approved status).
- **Attributes:**
  - `value` (bool)
  - `onChanged` (Function(bool))
- **Visuals:** Highly reactive, switching from gray pill track with dark handle to `AppColors.primary` container with white handle.

---

## 4. Cards & List Elements

### 4.1 `ArmsDashboardButton`
**Usage:** Grid/List cards on home screen that lead into specific modules.
- **Attributes:**
  - `title` (String)
  - `description` (String)
  - `icon` (IconData)
  - `iconBgColor` (Color)
  - `onTap` (VoidCallback)
- **Visuals:** `AppColors.cardSurface` background, 16px corner radius, large 56dp padding. Circular background for the icon.

### 4.2 `ArmsStudentRow` (Daily Attendance)
**Usage:** Dense, scannable student list row item showing avatar, roll number, and interactive state indicators.
- **Attributes:**
  - `studentName` (String)
  - `rollNo` (String)
  - `avatarUrl` (String?)
  - `attendanceStatus` (AttendanceStatus: Present, Absent, Unmarked)
  - `onStatusChanged` (Function(AttendanceStatus))
- **Visuals:** Rounded corners (12px), background: White, custom interactive 48dp P/A buttons. Highlight colors for states.

### 4.3 `ArmsLeaveCard`
**Usage:** Leave log listing with a student title, date range, brief description, and a semantic status badge.
- **Attributes:**
  - `applicantName` (String)
  - `dateRange` (String)
  - `reason` (String)
  - `status` (LeaveStatus: Pending, Approved, Rejected)
- **Visuals:** Background: `AppColors.cardSurface` (opacity reduced for approved/rejected state), custom rounded status badge.

### 4.4 `ArmsExamCard`
**Usage:** High-density assessment details block containing quick actions.
- **Attributes:**
  - `examTitle` (String)
  - `subjectSub` (String)
  - `date` (String)
  - `status` (ExamStatus: Saved, Draft)
  - `metaInfo` (List<String>) // e.g. Schools, Section, Marks
  - `onDownloadReport` (VoidCallback)
- **Visuals:** Multi-row grid layout inside a 12px rounded block, colored semantic status pill in top right corner.

### 4.5 `ArmsMarkEntryCard`
**Usage:** Score input entry block containing student details, absent options, and marks values.
- **Attributes:**
  - `studentName` (String)
  - `rollNo` (String)
  - `subjects` (List<String>)
  - `isAbsent` (bool)
  - `specialStatus` (MarkStatus: Normal, RNFP, Malpractice)
  - `onAbsentToggle` (Function(bool))
  - `onStatusToggle` (VoidCallback)
  - `marksControllers` (Map<String, TextEditingController>)
- **Visuals:** Score inputs are 48dp height white cards, absolute absent state locks down input values and dims widgets.

---

## 5. Layout & Informational Overlays

### 5.1 `ArmsStickyFooter`
**Usage:** Bottom docked button strip that overlays scrollable sheet views with summary details.
- **Attributes:**
  - `summaryWidget` (Widget?) // live counts (P: 24, A: 3)
  - `primaryButtonText` (String)
  - `onPrimaryPressed` (VoidCallback)
  - `secondaryButtonText` (String?)
  - `onSecondaryPressed` (VoidCallback?)
- **Visuals:** Docked background sheet, high-translucency blur (`backdropFilter`), padding matching `margin-page` (24px).

### 5.2 `ArmsActionBottomSheet`
**Usage:** Slide-up sheet with contextual actions (e.g. Edit Marks, PDF Report).
- **Attributes:**
  - `title` (String)
  - `subtitle` (String)
  - `actions` (List<ArmsBottomSheetActionItem>)
- **Visuals:** Slids up from bottom, top corners rounded by 32px, prominent centered drag bar (`AppColors.outline`).

### 5.3 `ArmsConfigHeader`
**Usage:** Header block detailing the selected active config (e.g. Series, date, class).
- **Attributes:**
  - `title` (String)
  - `details` (Map<String, String>)
  - `isLocked` (bool)
  - `onDoubleTapEdit` (VoidCallback)
- **Visuals:** Double-tap action activates overlay message showing a lock/unlock icon. Highlights with an active brand blue focus ring when active.
