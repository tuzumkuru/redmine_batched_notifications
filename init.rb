Redmine::Plugin.register :redmine_batched_notifications do
  name 'Redmine Batched Notifications plugin'
  author 'Tolga Uzun'
  description 'A Redmine plugin to batch issue update notifications.'
  version '0.1.0'
  url 'https://github.com/tuzumkuru/redmine_batched_notifications'
  author_url 'https://github.com/tuzumkuru'

  Rails.application.config.to_prepare do
    # Apply patches to Redmine core classes.
    require_dependency 'journal'
    require_dependency 'mailer'
    require 'journal_patch'
    require 'mailer_patch'
    Journal.send(:include, JournalPatch)
    Mailer.send(:include, MailerPatch)

    # Load ActiveJob classes.
    Dir[File.expand_path("#{__dir__}/app/jobs/**/*.rb")].each { |f| require_dependency f }
  end

  settings default: {
    'enabled' => 'true',
    'delay' => '60'  # Default delay in seconds.
  }, partial: 'settings/batched_notifications_settings'
end