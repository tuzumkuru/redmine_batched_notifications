Redmine::Plugin.register :redmine_batched_notifications do
  name 'Redmine Batched Notifications plugin'
  author 'Tolga Uzun'
  description 'A Redmine plugin to batch issue update notifications.'
  version '0.1.0'
  url 'https://github.com/tuzumkuru/redmine_batched_notifications'
  author_url 'https://github.com/tuzumkuru'

  settings default: {
    'enabled' => 'true',
    'delay' => '60'
  }, partial: 'settings/batched_notifications_settings'
end

Rails.application.config.after_initialize do
  require_relative 'lib/journal_patch'
  require_relative 'lib/mailer_patch'

  Journal.send(:include, JournalPatch)
  Mailer.send(:include, MailerPatch)

  Dir[File.expand_path("#{__dir__}/app/jobs/**/*.rb")].each { |f| require_dependency f }
end