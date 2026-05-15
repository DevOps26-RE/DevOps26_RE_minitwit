### Module View

This view illustrates the static package structure and dependency flow of the Minitwit codebase, adhering to Clean Architecture principles:

* **Core Application:** Encapsulates the pure business logic and domain entities (`User`, `Follower`, `Message`, `Application State`). It remains strictly isolated and framework-agnostic.
* **External Frameworks:** Infrastructure packages (`Gin` for HTTP routing, `Gorm` for database ORM, and `Prometheus` for metrics) depend *inward* on the Core Application. This ensures the domain logic is completely decoupled from specific technology choices.
* **Main Package:** Acts as the application's entry point, wiring up the necessary dependencies and triggering the core logic.

```mermaid
flowchart TB
%% ==========================================
%% Define Folders using Subgraphs with invisible nodes
%% ==========================================

subgraph PkgMain ["Main"]
N_Main[" "]
end

subgraph CoreApplication ["Core Application"]
direction TB
User[User]
Follower[Follower]
Message[Message]
ApplicationState[Application State]

%% Internal dependencies
User --> Follower
User --> Message
end

subgraph PkgGin ["Gin"]
N_Gin[" "]
end

subgraph PkgGorm ["Gorm"]
N_Gorm[" "]
end

subgraph PkgPrometheus ["Prometheus"]
N_Prom[" "]
end

%% ==========================================
%% Dependencies 
%% ==========================================

%% Main entry point triggers User logic
PkgMain --> User

%% Frameworks depending on Core Application (Clean Architecture inward flow)
PkgGin --> CoreApplication
PkgGorm --> CoreApplication
PkgPrometheus --> CoreApplication

%% ==========================================
%% FOLDER HACK: Make inner nodes completely invisible
%% ==========================================
style N_Main fill:none,stroke:none,color:transparent
style N_Gin fill:none,stroke:none,color:transparent
style N_Gorm fill:none,stroke:none,color:transparent
style N_Prom fill:none,stroke:none,color:transparent

%% Style the subgraphs to look more like solid packages
classDef packageStyle fill:#f8f9fa,stroke:#adb5bd,stroke-width:2px,color:#212529;
class PkgMain,PkgGin,PkgGorm,PkgPrometheus,CoreApplication packageStyle;
```