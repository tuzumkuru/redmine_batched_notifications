Redmine::Plugin.register :redmine_batched_notifications do
  name 'Redmine Batched Notifications plugin'
  author 'Tolga Uzun'
  description 'A Redmine plugin to batch issue update notifications.'
  version '0.1.0'
  url 'https://github.com/tuzumkuru/redmine_batched_notifications'
  author_url 'https://github.com/tuzumkuru'

  # Default plugin settings
  settings default: {
    'enabled' => 'true',
    'delay' => '60' # Default delay in seconds
  }, partial: 'settings/batched_notifications_settings'
end

# -----------------------------------------------------------------------------
# Load patches
# -----------------------------------------------------------------------------
def load_batched_notifications_patches
  puts "Loading batched notifications patches..."
  require_dependency 'journal'
  require_dependency 'mailer'
  require_relative 'lib/journal_patch'
  require_relative 'lib/mailer_patch'

  Journal.include(JournalPatch) unless Journal.included_modules.include?(JournalPatch)
  Mailer.include(MailerPatch) unless Mailer.included_modules.include?(MailerPatch)

  # Load jobs
  Dir[File.expand_path("#{__dir__}/app/jobs/**/*.rb")].each { |f| require_dependency f }
end

if Rails.env.test?
  # In test, load immediately (to_prepare may not trigger)
  load_batched_notifications_patches
else
  # In development/production, reload patches on each request (for dev reloading)
  Rails.application.config.to_prepare do
    load_batched_notifications_patches
  end
end
