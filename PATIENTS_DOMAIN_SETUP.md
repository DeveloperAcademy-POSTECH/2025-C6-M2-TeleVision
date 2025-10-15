# Patients Domain - Setup Instructions

## Overview
Complete Clean Architecture scaffolding for the Patients domain has been generated with proper folder structure, entities, use cases, repository implementation, and platform-specific UI views.

## Folder Structure Created

```
Hippo/
├── Shared/
│   ├── Domain/
│   │   └── Patients/
│   │       ├── Entities/
│   │       │   ├── Patient.swift
│   │       │   ├── Case.swift
│   │       │   └── ModelFile.swift
│   │       ├── Repositories/
│   │       │   └── PatientRepository.swift
│   │       └── UseCases/
│   │           ├── ListPatients.swift
│   │           ├── GetPatient.swift
│   │           ├── UpsertPatient.swift
│   │           ├── DeletePatient.swift
│   │           ├── UpsertCase.swift
│   │           ├── DeleteCase.swift
│   │           ├── AttachModelToCase.swift
│   │           └── RemoveModelFromCase.swift
│   ├── Data/
│   │   └── Patients/
│   │       ├── Repository/
│   │       │   └── PatientRepositoryImpl.swift
│   │       ├── DataSources/
│   │       │   ├── Local/
│   │       │   │   └── PatientLocalDataSource.swift
│   │       │   └── Remote/
│   │       │       └── PatientRemoteDataSource.swift
│   │       └── Mappers/
│   └── Presentation/
│       └── Patients/
│           ├── PatientState.swift
│           └── PatientViewModel.swift
└── Features/
    ├── VisionUI/
    │   └── Patients/
    │       └── PatientView.swift (visionOS-specific)
    └── MacUI/
        └── Patients/
            └── PatientView.swift (macOS-specific)
```

## Target Membership Configuration

### To Add Files to Xcode Project:

**IMPORTANT**: You need to manually add these files to the Xcode project with the following target memberships:

#### Files for BOTH Targets (HippoVision + HippoMac):

**Domain Layer:**
- `Hippo/Shared/Domain/Patients/Entities/Patient.swift` ✅ Both
- `Hippo/Shared/Domain/Patients/Entities/Case.swift` ✅ Both
- `Hippo/Shared/Domain/Patients/Entities/ModelFile.swift` ✅ Both
- `Hippo/Shared/Domain/Patients/Repositories/PatientRepository.swift` ✅ Both
- `Hippo/Shared/Domain/Patients/UseCases/ListPatients.swift` ✅ Both
- `Hippo/Shared/Domain/Patients/UseCases/GetPatient.swift` ✅ Both
- `Hippo/Shared/Domain/Patients/UseCases/UpsertPatient.swift` ✅ Both
- `Hippo/Shared/Domain/Patients/UseCases/DeletePatient.swift` ✅ Both
- `Hippo/Shared/Domain/Patients/UseCases/UpsertCase.swift` ✅ Both
- `Hippo/Shared/Domain/Patients/UseCases/DeleteCase.swift` ✅ Both
- `Hippo/Shared/Domain/Patients/UseCases/AttachModelToCase.swift` ✅ Both
- `Hippo/Shared/Domain/Patients/UseCases/RemoveModelFromCase.swift` ✅ Both

**Data Layer:**
- `Hippo/Shared/Data/Patients/Repository/PatientRepositoryImpl.swift` ✅ Both
- `Hippo/Shared/Data/Patients/DataSources/Local/PatientLocalDataSource.swift` ✅ Both
- `Hippo/Shared/Data/Patients/DataSources/Remote/PatientRemoteDataSource.swift` ✅ Both

**Presentation Layer:**
- `Hippo/Shared/Presentation/Patients/PatientState.swift` ✅ Both
- `Hippo/Shared/Presentation/Patients/PatientViewModel.swift` ✅ Both

#### Files for SPECIFIC Targets:

**visionOS Only (HippoVision):**
- `Hippo/Features/VisionUI/Patients/PatientView.swift` ✅ HippoVision only

**macOS Only (HippoMac):**
- `Hippo/Features/MacUI/Patients/PatientView.swift` ✅ HippoMac only

### Steps to Add Files in Xcode:

1. **Open Xcode Project**
   ```bash
   open Hippo.xcodeproj
   ```

2. **Add Shared Files (Domain, Data, Presentation)**
   - Right-click on `Hippo/Shared/Domain/Patients` folder in Xcode
   - Select "Add Files to Hippo..."
   - Navigate to the folder containing the files
   - Select all files in that folder
   - In the dialog:
     - ✅ Check "Copy items if needed" (should be unchecked since files are already in place)
     - ✅ Check "Create folder references"
     - ✅ Check BOTH targets: `HippoVision` and `HippoMac`
     - Click "Add"
   - Repeat for Data and Presentation layers

3. **Add VisionUI Files**
   - Right-click on `Hippo/Features/VisionUI/Patients` folder
   - Add `PatientView.swift`
   - ✅ Check ONLY `HippoVision` target

4. **Add MacUI Files**
   - Right-click on `Hippo/Features/MacUI/Patients` folder
   - Add `PatientView.swift`
   - ✅ Check ONLY `HippoMac` target

### Quick Add Script (Alternative):

You can also add files programmatically using this script:

```bash
# Navigate to project directory
cd /Users/eunsong/project/2025-C6-M2-TeleVision

# Add all files - this will open file dialogs for each
# Run this and follow the on-screen target membership selection
```

## Architecture Overview

### Entities
- **Patient**: Main entity with demographics, cases, and computed age
- **Case**: Medical case with diagnosis, scheduling, and model files
- **ModelFile**: 3D model file metadata with format support (USDZ, Reality, OBJ, FBX, STL, DICOM)

### Use Cases (DI-ready with swift-dependencies)
- **ListPatients**: Fetch all patients
- **GetPatient**: Get single patient by ID
- **UpsertPatient**: Create or update patient
- **DeletePatient**: Remove patient
- **UpsertCase**: Add/update case to patient
- **DeleteCase**: Remove case from patient
- **AttachModelToCase**: Attach 3D model to case
- **RemoveModelFromCase**: Remove model from case

### Repository Pattern
- **Interface**: `PatientRepository` protocol in Domain layer
- **Implementation**: `PatientRepositoryImpl` with offline-first strategy
  - Local-first: Returns local data immediately
  - Background sync: Syncs with remote in background
  - Conflict resolution: Remote wins if `updatedAt` is newer

### Data Sources
- **Local**: JSON file storage (can migrate to SwiftData - see TODO comments)
- **Remote**: CloudKit stubs (implement sync logic - see TODO comments)

### Presentation Layer
- **State**: Immutable state with loading/error handling
- **ViewModel**: `@Observable` with dependency injection, async operations

### UI Views
- **visionOS**: List-based UI with glass background effect
- **macOS**: Table-based UI with detail pane

## TODO Items for Full Implementation

### 1. CloudKit Integration
**Location**: `Hippo/Shared/Data/Patients/DataSources/Remote/PatientRemoteDataSource.swift`

Implement:
- `pullAll()`: Fetch records from CloudKit
- `push()`: Save/update records to CloudKit
- `remove()`: Delete records from CloudKit
- Add CloudKit mappers for Patient/Case/ModelFile entities

### 2. SwiftData Migration (Optional)
**Location**: `Hippo/Shared/Data/Patients/DataSources/Local/PatientLocalDataSource.swift`

Consider migrating from JSON to SwiftData for:
- Better performance
- Query capabilities
- Relationships
- Migrations

Uncomment and complete the SwiftData implementation section.

### 3. Error Handling Enhancement
Add proper error types and handling:
```swift
public enum PatientError: Error {
    case notFound
    case networkError(Error)
    case persistenceError(Error)
    case syncConflict
}
```

### 4. Testing
Create test files:
- `PatientRepositoryTests.swift`
- `PatientViewModelTests.swift`
- Use `testValue` dependencies for testing

## Usage Example

```swift
import SwiftUI

@main
struct HippoApp: App {
    var body: some Scene {
        WindowGroup {
            PatientView()
        }
    }
}
```

The `PatientView` is already set up with:
- Automatic data loading on appear
- Add/delete patient functionality
- Error alerts
- Loading states
- Platform-specific UI (List for visionOS, Table for macOS)

## Dependencies

The project uses `swift-dependencies` for dependency injection:
- Already configured in project
- All use cases have `liveValue` and `testValue` implementations
- Automatic dependency resolution

## Next Steps

2.  Build project to verify no compilation errors
3.  Implement CloudKit sync (when ready for remote sync)
4.  Consider SwiftData migration (for better local storage)
5.  Add comprehensive tests
6.  Enhance error handling and logging
7.  Add model file upload/download functionality
