# GitLab Webhook Management Scripts

This repository contains 3 scripts to manage webhooks in GitLab projects:

- [hook-add.sh](hook-add.sh): Adds a webhook to a list of projects.
- [hook-update.sh](hook-update.sh): Adds or Updates a webhook on a list of projects, copying permissions from an existing hook (Reference URL) to a new Target URL on the same project.
 Optional, you can set a webhook secret 
- [hook-delete.sh](hook-delete.sh): Deletes a webhook from a list of projects.
- [set-env.sh.template](set-env.sh.template): Common configurations for both hook script (above). 
>  cp set-env.sh.template set-env.sh

## Architecture Migration

These scripts allow for moving from a Monolithic CI Controller reference to Dedicated Controllers per project/team.

```mermaid
flowchart TD

    subgraph Future ["Future State (Distributed)"]
        direction TB
        F_P1[Project 1]
        F_P2[Project 2]
        F_P3[Project 3]
        
        C1[Controller Team A]
        C2[Controller Team B]
        C3[Controller Team C]
        
        F_P1 -->|Refers to| C1
        F_P2 -->|Refers to| C2
        F_P3 -->|Refers to| C3
    end

    subgraph Current ["Current State (Monolith)"]
        direction TB
        M_P1[Project 1]
        M_P2[Project 2]
        M_P3[Project 3]
        Monolith[CI Controller Monolith]
        
        M_P1 & M_P2 & M_P3 -->|Refers to| Monolith
    end
    
    style Current fill:#f9f2f4,stroke:#333,stroke-width:2px
    style Future fill:#e1f7d5,stroke:#333,stroke-width:2px
```

## Workflow Diagram

```mermaid
flowchart TD
    User((Operator))
    Config[Configuration set-env.sh]
    
    subgraph Scripts
        Add[hook-add.sh]
        Update[hook-update.sh]
        Delete[hook-delete.sh]
    end
    
    subgraph GitLab["GitLab API"]
        RefProject[Reference WebHook]
        TargetProjects[Target WebHook]
    end

    User -->|Configures| Config
    Config --> Add
    Config --> Update
    Config --> Delete
    
    Add -->|Checks existence| TargetProjects
    Add -->|POST if missing| TargetProjects
    
    Update -->|1. List Hooks| TargetProjects
    Update -->|2. Extract Config from Ref URL| TargetProjects
    Update -->|3. POST/PUT to Target URL| TargetProjects
    
    Delete -->|Checks existance| TargetProjects
    Delete -->|DELETE if found| TargetProjects
    
    style Add fill:#d4f1f4,stroke:#000,stroke-width:2px
    style Update fill:#d4f1f4,stroke:#000,stroke-width:2px
    style Delete fill:#f4d4d4,stroke:#000,stroke-width:2px
```

## Configuration

Create your copy of the `set-env.sh`and adjust your variables
    
```bash
  cp set-env.sh.template set-env.sh
```
Both scripts read their configuration from the top of the file. You need to set the following variables in `set-env.sh`:

- `GITLAB_TOKEN`: Your GitLab Personal Access Token with `api` scope.
- `WEBHOOK_TARGET`: The URL of the webhook to add or delete.
- `PROJECTS`: A list of project paths or numeric IDs.

**For `hook-update.sh` specifically:**
- `WEBHOOK_REFERENCE_URL`: The URL of the existing hook to copy permissions from.
- `WEBHOOK_SECRET`: (Optional) The secret token for the hook.

## Usage

2. Make the scripts executable:
```bash
chmod +x hook-add.sh
chmod +x hook-delete.sh
chmod +x hook-update.sh
```
3. Run the desired script:
```bash
./hook-add.sh
./hook-delete.sh
./hook-update.sh
```
