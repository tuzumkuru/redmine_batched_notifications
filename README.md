# Redmine Batched Notifications Plugin

This plugin for Redmine helps reduce the volume of email notifications by batching updates for a single issue into a single email. When multiple edits are made to an issue by a user within a short timeframe, instead of sending an email for each update, the plugin waits for a configurable period and then sends one summary email containing all the changes.

## How it Works

Instead of sending an email instantly for every issue update, this plugin waits for a short, configurable period. If more updates are made to the same issue by the same user during that time, it groups them all into a single, summary email. This prevents users from being flooded with notifications for rapid, minor changes. The plugin also ensures that private notes are only sent to users with the appropriate permissions.

## Installation

1.  Clone this repository into your Redmine `plugins` directory.
    ```sh
    git clone https://github.com/tuzumkuru/redmine_batched_notifications.git plugins/redmine_batched_notifications
    ```
2.  Run the plugin migrations:
    ```sh
    bundle exec rake redmine:plugins:migrate
    ```
3.  Restart your Redmine application.

## Configuration

The plugin can be configured from the Redmine administration panel (`Administration -> Plugins -> Redmine Batched Notifications -> Configure`):

*   **Enabled:** Turn the batching functionality on or off globally.
*   **Delay (seconds):** The time to wait for more changes before sending a notification. Each new change on an issue by the same user will reset this timer.

## Development Environment (Docker)

A Docker-based development environment is provided for convenience.

1.  **Start the services:**
    ```bash
    docker compose up -d
    ```

2.  **Run the setup script:**
    This script will set up the Redmine instance with some test data.
    ```bash
    docker compose exec redmine /usr/src/redmine/plugins/redmine_batched_notifications/docker/setup_redmine_dev.sh
    ```

3.  **Access the services:**
    *   **Redmine:** `http://localhost:3000`
        *   Admin: `admin` / `admin`
        *   Test users: `testuser1` / `password`, `testuser2` / `password`
    *   **MailHog (email catcher):** `http://localhost:8025`

4.  **Stopping the environment:**
    ```bash
    docker compose down
    ```

## Testing

The plugin includes a set of tests to ensure its functionality. The tests are run inside the Docker container to ensure a consistent environment.

1.  **Start the services:**
    ```bash
    docker compose up -d
    ```

2.  **Run the setup script for tests:**
    This script will set up the Redmine test database.
    ```bash
    docker compose exec redmine /usr/src/redmine/plugins/redmine_batched_notifications/docker/setup_redmine_tests.sh
    ```

3.  **Run all tests for the plugin:**
    ```bash
    docker compose exec redmine bundle exec rake redmine:plugins:test NAME=redmine_batched_notifications
    ```