# iOS Keyboard Pre-Warming

## Symptom

On a **fresh install** of the app, the very first tap on a `TextField` (e.g. the email field on `LoginView`) takes ~700 ms to show the keyboard. Every subsequent focus — even after terminating and relaunching the app — takes ~300 ms.

## Root cause

Captured with a System Trace on iOS 26.3 (`trace_2026-05-14-1049253.trace`). The first focus produces a single 649 ms main-thread hang on the app, during which:

1. `kbd` (the system keyboard daemon) is woken ~430 ms into the hang.
2. `InputUI.app` (the keyboard UI extension at `/Applications/InputUI.app/InputUI`) is **cold-spawned as a brand-new process** — no warm process exists to recycle on first install.
3. Inside the app's address space, AutoFillCore, AutoFillUI, RemoteUI, ContactsAutocomplete, GenerativeModels, FoundationModels, and IntelligencePlatform are loaded for the first time. `UIKeyboardImpl` synchronously initializes this AutoFill / Apple Intelligence / Contacts-autocomplete plumbing on the main thread when a `UITextField` becomes first responder for the first time.

After this first focus the `InputUI` process stays warm system-wide and the framework init is cached per app — this is why the cost does not recur after termination, and only resets on reinstall.

## Mitigation: pre-warm during onboarding

The cheapest fix is to trigger the cold path while the user is looking at something else (splash, onboarding, logo animation) instead of when they tap the email field. Briefly make a hidden `UITextField` first responder, then resign:

```swift
import UIKit

enum KeyboardPrewarmer {
    static func prewarm() {
        DispatchQueue.main.async {
            let field = UITextField(frame: .zero)
            field.textContentType = .emailAddress // match LoginView so AutoFill init runs
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .addSubview(field)
            field.becomeFirstResponder()
            field.resignFirstResponder()
            field.removeFromSuperview()
        }
    }
}
```

Call `KeyboardPrewarmer.prewarm()` once from the onboarding view's `.onAppear` (or the splash screen). The `InputUI` extension cold-launch and the AutoFill/Intelligence framework init happen in the background during onboarding, so by the time the user reaches `LoginView` the cost is already paid.

### Why onboarding is the right place

- We only pay the 700 ms cost on first install — same trigger as showing onboarding.
- No need to slow down `HauptgangApp` `init` or first-frame for returning users.
- If the user dismisses onboarding before the prewarm finishes, the worst case is the original behavior — there is no regression.

## Alternative mitigations (not chosen)

- **Drop `.textContentType(.emailAddress)`** on the email field — skips the AutoFill inference but loses QuickType email suggestions. Smaller win, real UX cost.
- **Move Sentry's `app-hang-tracker` init off the main thread** — minor contributor in the trace, not the dominant cost.

## Verification

Re-capture a System Trace on a fresh install with onboarding-time prewarm enabled. Expect:

- A ~600 ms hang **during onboarding** (acceptable — user isn't interacting with input).
- The first email-field tap on `LoginView` should match the warm-path cost (~300 ms), with no `InputUI` process-launch event.
