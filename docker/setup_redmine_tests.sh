#!/bin/sh

# This script prepares the Redmine Docker container for running plugin tests.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "---> 1. Installing system dependencies for testing..."
# Check if build-essential is installed, if not, install it.
if ! dpkg -s build-essential >/dev/null 2>&1; then
  echo "Installing build-essential..."
  apt-get update && apt-get install -y build-essential
else
  echo "build-essential is already installed."
fi

echo "---> 2. Configuring Bundler for test environment..."
bundle config set --local without development

echo "---> 3. Installing gems for test environment..."
bundle install

echo "---> 4. Preparing test database..."
export RAILS_ENV=test
bundle exec rake db:test:prepare

echo "
--- Test setup complete! ---
"