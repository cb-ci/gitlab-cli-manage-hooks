# GitLab Webhook Management Scripts

This repository contains two scripts to manage webhooks in GitLab projects:

- [hook-add.sh](hook-add.sh): Adds a webhook to a list of projects.
- [hook-delete.sh](hook-delete.sh): Deletes a webhook from a list of projects.

## Configur

Create your copy of the `set-env.sh`and adjust your variables
    ```bash
    cp set-env.sh.template set-env.sh.
    ```
Both scripts read their configuration from the top of the file. You need to set the following variables in `set-env.sh`:

- `GITLAB_TOKEN`: Your GitLab Personal Access Token with `api` scope.
- `WEBHOOK_TARGET`: The URL of the webhook to add or delete.
- `PROJECTS`: A list of project paths or numeric IDs.

## Usage

2. Make the scripts executable:
    ```bash
    chmod +x hook-add.sh
    chmod +x hook-delete.sh
    ```
3. Run the desired script:
    ```bash
    ./hook-add.sh
    ./hook-delete.sh
    ```
