# Redmine Batched Notifications Plugin

This plugin for Redmine batches issue notification emails to reduce the volume of messages sent when multiple edits occur in a short period.

## Installation

1. Add this repository as a submodule to your Redmine `plugins` directory:
   ```sh
   git -C plugins submodule add https://github.com/tuzumkuru/redmine_batched_notifications.git
   ```
2. Run the plugin migrations:
   ```sh
   bundle exec rake redmine:plugins:migrate
   ```
3. Restart your Redmine application.
