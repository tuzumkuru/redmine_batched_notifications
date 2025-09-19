# Redmine Batched Notifications Plugin

This plugin for Redmine helps reduce the volume of email notifications by batching updates for a single issue into a single email. When multiple edits are made to an issue by a user within a short timeframe, instead of sending an email for each update, the plugin waits for a configurable period and then sends one summary email containing all the changes.

## How it Works

The plugin's mechanism is designed to intercept and delay notifications to batch them effectively:

1.  **Intercepting Notifications:** The plugin patches Redmine's `Journal` model to prevent immediate email notifications for issue updates. Instead of sending an email, it creates a `PendingNotification` record in the database for each change.

2.  **Scheduling a Job:** When a `PendingNotification` is created, a `SendBatchedNotificationsJob` is scheduled to run after a configurable delay (default is 60 seconds). This job is responsible for sending the batched email. If other changes are made to the same issue by the same user before the job runs, the job's execution time is pushed back, effectively resetting the delay timer.

3.  **Sending Batched Emails:** When the `SendBatchedNotificationsJob` executes, it gathers all pending notifications for that specific issue and user. It then generates a single email that includes all the journal entries (updates, notes, etc.) that were created during the batching period.

4.  **Handling Private Notes:** The plugin is careful to respect Redmine's permissions. When batching notifications, it checks if a journal contains a private note. The email sent to each user will only include the private note if that user has the permission to view private notes in that project.

## Configuration

The plugin can be configured from the Redmine administration panel (`Administration -> Plugins -> Redmine Batched Notifications -> Configure`):

*   **Enabled:** Turn the batching functionality on or off globally.
*   **Delay (seconds):** The time to wait for more changes before sending a notification. Each new change on an issue by the same user will reset this timer.

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
