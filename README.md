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

## Development Environment (Docker)

To set up and run your Redmine development environment with this plugin using Docker:

1. **Ensure Docker and Docker Compose are installed** on your system.

2. **Navigate to the project root** (where `docker-compose.yml` is located).

3. **Run the containers**:
   This command pulls the `redmine:6.0` image (latest stable), `postgres:16-alpine` (latest PostgreSQL), and `mailhog/mailhog` (latest for email testing), and starts the services.
   ```bash
   docker compose up -d
   ```

4. **Wait for Redmine to start** (check logs with `docker compose logs redmine` to ensure no DB errors).

5. **Run the setup script** (manual step to avoid interfering with Redmine's startup):
   ```bash
   docker compose exec redmine /usr/src/redmine/setup_redmine_dev.sh
   ```
   This script:
   - Loads default Redmine data in English.
   - Runs DB and plugin migrations.
   - Creates three users (admin, testuser1, testuser2).
   - Disables `must_change_passwd` for all users.
   - Creates a test project ("Test Project").
   - Adds all users to the project as developers.
   - Creates an initial issue.

6. **Access Redmine**: Open your web browser and go to `http://localhost:3000`.
   - Admin login: `admin`/`admin`
   - Test user logins: `testuser1`/`password`, `testuser2`/`password`

### Docker Volumes
- Data is stored locally in `docker/vol/` (ignored by Git) for persistence:
  - `docker/vol/db_data`: PostgreSQL database.
  - `docker/vol/redmine_data`: Redmine files/uploads.
- To reset data, delete `docker/vol/`.

### Running Migrations Manually
If you update the plugin and need to run migrations:

1. Install new gems (if you've added dependencies to the Gemfile):
   ```bash
   docker compose exec redmine bundle install
   ```

2. Run DB migrations from your host console:
   ```bash
   docker compose exec redmine bundle exec rake db:migrate RAILS_ENV=production
   ```

3. Run plugin migrations from your host console:
   ```bash
   docker compose exec redmine bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

### Verifying Batched Notifications (with MailHog)
To check if the Redmine Batched Notifications plugin is working:

1. **Access MailHog UI**: Open `http://localhost:8025` for intercepted emails.

2. **Configure Redmine for notifications**:
   - Log in as admin at `http://localhost:3000`.
   - Go to "Administration" > "Settings" > "Email notifications".
   - Enable notifications; MailHog is auto-configured.

3. **Trigger notifications**:
   - Edit the test issue multiple times quickly.
   - Check MailHog for batched emails (single email per user with summary).

### Stopping the Environment
```bash
docker compose down
```

**Notes**:
- The setup script is idempotent (safe to re-run).
- For production, adjust configs and remove dev-specific settings.
- If issues arise, check logs: `docker compose logs`.