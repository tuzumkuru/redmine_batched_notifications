#!/bin/bash

# This script performs initial setup tasks for Redmine development environment.
# Run manually after the container is ready.

# Idempotency check: Skip if setup already done
if [ -f /usr/src/redmine/.setup_done ]; then
  echo "Setup already completed. Exiting."
  exit 0
fi

# Load default data (ensure roles are present)
bundle exec rake redmine:load_default_data RAILS_ENV=production --trace REDMINE_DEFAULT_LANGUAGE=en

# Run database migrations
echo "Running database migrations..."
bundle exec rake db:migrate RAILS_ENV=production

# Run plugin migrations
echo "Running plugin migrations..."
bundle exec rake redmine:plugins:migrate RAILS_ENV=production

# Create three users (if they don't exist)
echo "Creating users..."
bundle exec rails runner "
  User.find_or_create_by(login: 'admin') do |u|
    u.firstname = 'Admin'; u.lastname = 'User'; u.mail = 'admin@example.com'; u.password = 'admin'; u.password_confirmation = 'admin'; u.admin = true
  end
  User.find_or_create_by(login: 'testuser1') do |u|
    u.firstname = 'Test'; u.lastname = 'User1'; u.mail = 'testuser1@example.com'; u.password = 'password'; u.password_confirmation = 'password'; u.admin = false
  end
  User.find_or_create_by(login: 'testuser2') do |u|
    u.firstname = 'Test'; u.lastname = 'User2'; u.mail = 'testuser2@example.com'; u.password = 'password'; u.password_confirmation = 'password'; u.admin = false
  end
" RAILS_ENV=production

# Disable must_change_passwd for ALL users
echo "Disabling password change requirement for all users..."
bundle exec rails runner "User.update_all(must_change_passwd: false)" RAILS_ENV=production

# Create a test project (if it doesn't exist)
echo "Creating test project..."
bundle exec rails runner "
  project = Project.find_or_create_by(identifier: 'test_project') do |p|
    p.name = 'Test Project'; p.description = 'A project for testing batched notifications'; p.is_public = true
  end
" RAILS_ENV=production

# Add all users to the project as developers (role ID 2)
echo "Adding users to test project as developers..."
bundle exec rails runner "
  project = Project.find_by(identifier: 'test_project')
  role = Role.find_by(id: 4)  # Developer role
  User.where(login: %w[admin testuser1 testuser2]).each do |user|
    unless project.members.exists?(user: user)
      project.members.create(user: user, roles: [role])
    end
  end
" RAILS_ENV=production

# Create an initial issue in the project
echo "Creating initial issue..."
bundle exec rails runner "
  project = Project.find_by(identifier: 'test_project')
  tracker = project.trackers.first || Tracker.first  # Use first available tracker
  Issue.find_or_create_by(subject: 'Test Issue') do |i|
    i.project = project; i.tracker = tracker; i.author = User.find_by(login: 'admin'); i.description = 'This is a test issue for batched notifications.'
  end
" RAILS_ENV=production

# Mark setup as done
touch /usr/src/redmine/.setup_done
echo "Setup completed successfully."