# Swift Reading App — AI Rules (Swift 6.2)

## Language and Platform

- **Swift version**: Swift 6.2  
- **Platform**: iOS  
- **UI framework**: SwiftUI  

## Project Context

This is a production-grade iOS reading application.  
Primary goals are smooth reading performance, strong offline support, modern Swift architecture, and high testability.  
All code must follow modern Swift 6.2 best practices.

---

## GENERAL PRINCIPLES

- Prefer clarity over cleverness.  
- Match existing project patterns and naming conventions.  
- Do not introduce new abstractions unless they clearly reduce complexity.  
- Write code that is easy to test, refactor, and review.  
- Prefer simple, direct solutions over generic or overly abstract designs.  

---

## FUNCTIONS & APIS

- Functions must do one thing.  
- Keep functions under ~40 lines unless strongly justified.  
- Prefer pure functions when possible.  
- Avoid deep nesting; prefer early returns.  

---

## OBSERVATION AND STATE MANAGEMENT

### MUST USE

- Swift Observation framework  
- `@Observable` macro for all observable models  

### MUST NOT USE (NOT PERMITTED)

- `ObservableObject`  
- `@Published`  
- `@StateObject`  
- `@ObservedObject`  
- `@EnvironmentObject`  

### Rules

- All application state must live inside `@Observable` types.  
- Observation is applied at the type level, never per property.  
- SwiftUI views bind directly to observable properties.  
- Mixing Combine-based observation with Observation is NOT allowed.  

### Allowed Exception

- `@Bindable` IS PERMITTED and recommended for two-way binding.

---

## CONCURRENCY MODEL (SWIFT 6.2)

### MUST USE

- Swift Structured Concurrency  
- `async`/`await`  
- `Task { }`  

### MUST NOT USE (NOT PERMITTED)

- `DispatchQueue.main.async`  
- `DispatchQueue.global()`  
- Any `DispatchQueue` usage  
- Manual thread management  
- `RunLoop` or `RunLoop`-based concurrency  

### Rules

- UI state must be isolated to the main actor.  
- ViewModels that update UI must be annotated with `@MainActor`.  
- Never manually dispatch back to the main thread.

---

## ARCHITECTURE

- Use **MVVM**.  

### Layers

- **Views**: UI only  
- **ViewModels**: state and user intent  
- **Domain/Services**: business logic  
- **Repositories**: data access  

### Rules

- Views must contain ZERO business logic.  
- ViewModels must NOT perform networking or persistence directly.  
- Dependencies must be injected through initializers.

---

## SWIFTUI RULES

- Views must be small and composable.  
- No heavy computation inside view bodies.  
- Async UI actions must use `Task`.  
- Use `NavigationStack` only.

---

## DATA AND OFFLINE SUPPORT

- Offline reading is mandatory.  

### Persist

- Reading position  
- Bookmarks  
- Highlights  
- Reading preferences  

### Rules

- Repositories expose async APIs.  
- Prefer local data over network.

---

## ERROR HANDLING

- Define domain-specific error types.  
- Errors must never be ignored.  
- User-facing messages must be clear.

---

## TESTING

- Core logic must be testable without SwiftUI.  
- Prefer unit tests.

---

## SECURITY AND PRIVACY

- Store sensitive data in Keychain.  
- Do not log book contents or personal data.

---

## AI OUTPUT RULES

When generating code:

1. List files to change.  
2. Provide one file per code block.  
3. Brief explanation.

---

## ABSOLUTE PROHIBITIONS

- `ObservableObject` and `@Published` are **NOT PERMITTED**.  
- `DispatchQueue` and `RunLoop` are **NOT PERMITTED**.  
- Force unwrap (`!`) and `try!` are **NOT PERMITTED**.  
- Business logic inside Views is **NOT PERMITTED**.  
- Invented APIs are **NOT PERMITTED**.
