# Project Rules and Architectural Guidelines

## 1. Architecture: Clean Architecture
This project follows strict Clean Architecture principles to ensure scalability, maintainability, and testability.

### Layers
The project is divided into three main layers:

#### A. Presentation Layer (`lib/features/{feature}/presentation`)
- **Responsibility**: UI rendering and handling user interactions.
- **Components**:
    - **Pages/Screens**: Flutter Widgets that represent a full screen.
    - **Widgets**: Reusable UI components.
    - **Providers/Notifiers**: `ChangeNotifier` classes that manage state for the UI. DO NOT place business logic here. Delegate to UseCases.
- **State Management**: **Provider**. Use `Consumer` or `Selector` to listen to state changes.

#### B. Domain Layer (`lib/features/{feature}/domain`)
- **Responsibility**: Pure business logic. Independent of Flutter or any data source.
- **Components**:
    - **Entities**: Pure Dart objects representing the core business data.
    - **Repositories (Interfaces)**: Abstract definitions of how data is accessed.
    - **UseCases**: Encapsulate a specific business rule or action (e.g., `LoginUser`, `GetInvoices`). Single responsibility principle.
    - **Failures**: Definition of potential errors (e.g., `ServerFailure`, `CacheFailure`).

#### C. Data Layer (`lib/features/{feature}/data`)
- **Responsibility**: Data retrieval and storage.
- **Components**:
    - **Models**: Extensions of Entities with JSON serialization/deserialization logic (`fromJson`, `toJson`).
    - **Repositories (Implementations)**: Implement the interfaces defined in the Domain layer.
    - **DataSources**: Low-level data access (e.g., `RemoteDataSource` for API, `LocalDataSource` for DB).

## 2. Dependency Injection
- Use **GetIt** (`get_it`) as the Service Locator.
- Register dependencies in a centralized `injection_container.dart` or feature-specific injection files.
- Inject dependencies into UseCases and Repositories via constructor injection.

## 3. Directory Structure
```
lib/
  core/               # Shared logic (constants, error handling, base classes)
    error/
    usecases/
    utils/
  features/           # Feature-based organization
    feature_name/
      data/
        datasources/
        models/
        repositories/
      domain/
        entities/
        repositories/
        usecases/
      presentation/
        pages/
        providers/
        widgets/
  main.dart
  injection_container.dart
```

## 4. Coding Standards
- **Lints**: Follow strict Flutter lints.
- **Imports**: Use absolute paths (`package:xloop_invoice/...`) preferrable over relative paths for cleanliness, except for within the same directory.
- **Comments**: Document public APIs and complex logic.
- **Testing**: Every UseCase and Repository implementation should have accompanying unit tests.

## 5. State Management Rules
- **Provider**:
    - Extend `ChangeNotifier`.
    - Expose strictly necessary state variables.
    - Use `notifyListeners()` only when actual state changes.
    - Inject `UseCases` into the `ChangeNotifier`.
