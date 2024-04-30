Version 2.1.14 (upcoming)
  * Allow user-configurable extra memory:  Issue 95
  * Make haptic feedback the more iOS-friendly selection feedback
  * 16C:  Don't reset G flag when entering number:  Issue 98
  * 16C:  Fix WINDOW in program:  Issue 94
  * Cosmetic fixes:  Issues 93, 92
  * Run conditional operations ouside program: Issue 97

Version 2.1.13
  * Allow "," as keyboard accelerator in Euro comma mode:  Issue 90
  * 16C - Implement leading zeros (flag 3) on integer number entry:  Issue 89

Version 2.1.12
  * Implement FP addition and subtraction in decimal:  Issue 78
  * Limit FP digit entry even when not in windowed mode:  Issue 79
  * 15C:  Check for overflow on complex operations
  * 15C:  Check common pool availability when doing solve, integrate
    from the keyboard:  Issue 86
  * 15C:  Fix matrix solve when result matrix is an arg matrix:  Issue 84
  * 16C:  Display 0xc as "C", not "c":  Issue 76
  * 16C:  In 1's complement decimal, give -0 from "0 CHS":  Issue 85
  * Copy/paste improvements:  Issue 83
  * Other small issues/enhancements:  Issues 79, 80, 81, 82
  * Github action for APK builds:  Issue 73.  This changes the APK signing key.

Version 2.1.11
  * 16C:  More robust handling on invalid floats in registers:  Issue 70

Version 2.1.10
  * Add stricter checks of internal float format:  Issue 68
  * Give infinity (and not error) for tan(90 degrees):  Issue 69

Version 2.1.9
  * Add permission needed on some Android phones for haptic feedback.
  * Add option for heavy haptic feedback.
  * Fix FIX/ENG/SCI I:  Issue 65

Version 2.1.8
  * Add ability to grow LCD and, on the 16C, show large binary numbers on
    two lines.
  * Add user guide to explain menu options.

Version 2.1.7
  * 16C:  More realistic signed decimal integer mode number entry on overflow (Issue 53)
  * Desktop:  Autosave on window close via new API (Issue 46)

Version 2.1.6
  * Fix bug with SST in calculator mode (Issue 48)
  * Give exact results for trig functions in degrees at
    zero points and infinity (0, 90, 180, 270) (Issue 49).
  * Android:  Open about page and bug page in external
    browser (Issue 51).

Android only, Version 2.1.5
  * Automatically save state on app lifecycle notification
  * Request internet permission so that links from help menu work (Issue 50)

Both, Version 2.1.4
  * Support haptic key feedback in addition to click.
  * Avoid confusion by autosaving calculator state when settings changed.
  * Improvements to numerical integration.
  * Nicer Android icons.

15C only, Version 2.1.3:
  * Backspace key clears flashing error/overflow (Issue 34)

Both, Version 2.1.2:
  * Small cleanups and packaging for release.
  * Improved floating point number entry with window enabled (Issue 33).

Both, version 2.1.0:
  * Created 15C simulator using a common codebase.
  * Deploying to Microsoft app store and Linux snap store, in addition to
    Google's Android store.
  * Added "view calculator internals" screen.
  * Added program import/export feature.
  * Audible key press feedback on Android, if enabled in system settings.
  * In 16C integer mode, made comma display an option that defaults to off,
    to align with real 16C (issue 19)
  * Made the colors of the F and G keys and the LCD display configurable.
  * Various small bugfixes (issues 13, 15, 21, 22, 28).
  

16C 2.0.2:
  *  Improved handling of floating point overflow
