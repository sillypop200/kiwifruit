# LLM Rules and Prompts

This page documents the rules and guidelines for using LLMs in the KiwiFruit project development.

---

## Project AI Rules

KiwiFruit follows strict modern Swift 6.2 development practices. All AI-generated code and team development must adhere to these rules.

---

## Swift Reading App — AI Rules (Swift 6.2)

### Language and Platform  
- **Swift version**: Swift 6.2  
- **Platform**: iOS  
- **UI framework**: SwiftUI  

### Project Context  
This is a production-grade iOS reading application.  
Primary goals are smooth reading performance, strong offline support, modern Swift architecture, and high testability.  
All code must follow modern Swift 6.2 best practices.

### Citation Requirement
**Please provide citation if any rules are provided by others, including LLMs. 10%**

### Citation  
This LLM Rule is created based on Slide 10 and Slide 11 of C6.2-StoryMap. Some rules are adapted from the "LLM Prompts and Rule File" section. General principles are co-written with Claude.

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

### Allowed Exceptions  
- `@Bindable` IS PERMITTED and recommended for two-way binding.
- `@Binding` IS PERMITTED for two-way binding. `@Bindable` is already part of the new Observation package, but it doesn't hurt to list it explicitly.

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

### Pattern
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

### MUST NOT USE (NOT PERMITTED)
- `GeometryReader`
- `ZStack` (allowed ONLY if implementing View elevation or other features requiring z-axis differentiation)

---

## DATA AND OFFLINE SUPPORT

### Requirements
- Offline reading is mandatory.  

### Must Persist  
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
- `GeometryReader` is **NOT PERMITTED**.
- `ZStack` is **NOT PERMITTED** (exception: View elevation or z-axis differentiation only).

---

## LLM Usage Declaration

### LLMs Used in This Project

We have used the following AI tools to assist in development:

1. **Claude (Anthropic)**
   - Version: Claude 3.5 Sonnet / Claude 3 Opus
   - Primary Use: Architecture design, code generation, debugging assistance
   - Usage: ~60% of initial scaffolding and boilerplate code

2. **GitHub Copilot**
   - Primary Use: Auto-completion and inline suggestions
   - Usage: Ongoing throughout development for routine code patterns

3. **ChatGPT (OpenAI)**
   - Version: GPT-4
   - Primary Use: Documentation generation, API design discussions
   - Usage: ~30% of documentation and planning phases

---

## Development Workflow with AI

### Phase 1: Architecture & Planning
- Used LLMs to discuss architecture patterns
- Validated modern Swift 6.2 approaches
- Designed data flow and state management strategy

### Phase 2: Code Generation
- Generated initial view templates following SwiftUI best practices
- Created ViewModels with `@Observable` macro
- Implemented async/await networking patterns

### Phase 3: Refinement
- AI-assisted refactoring to eliminate anti-patterns
- Code review suggestions for Swift 6.2 compliance
- Performance optimization recommendations

### Phase 4: Testing & Documentation
- Test case generation
- Documentation writing and formatting
- Wiki page structuring

---

## Key Prompts Used

### Architecture Setup
```
Design an iOS reading app architecture using Swift 6.2:
- Use @Observable instead of ObservableObject
- MVVM pattern with dependency injection
- Async/await for all concurrency
- Offline-first data persistence
- No DispatchQueue usage
```

### State Management
```
Create a ViewModel for [feature] following Swift 6.2 observation:
- Use @Observable macro at type level
- Annotate with @MainActor for UI updates
- Use async/await for data operations
- Inject repository dependencies
```

### View Generation
```
Create a SwiftUI view for [feature]:
- Small, composable components
- Zero business logic
- Bind directly to @Observable properties
- Use Task for async actions
```

---

## Honor Code Statement

We affirm that:
- All AI usage has been disclosed above
- Generated code has been reviewed and understood by team members
- We take full responsibility for all code in the project
- AI tools were used as assistants, not replacements for learning

---

*Last Updated: February 11, 2026*  
*Team: Team Kiwifruit*
