

Redmine::Plugin.register :redmine_batched_notifications do
  name 'Redmine Batched Notifications plugin'
  author 'Gemini'
  description 'This is a plugin for Redmine that batches issue update notifications.'
  version '0.0.1'
  url 'https://github.com/google/gemini-cli'
  author_url 'https://gemini.google.com'

  Rails.application.config.to_prepare do
    # Patches
    require_dependency 'journal'
    require_dependency 'mailer'
    require 'journal_patch'
    require 'mailer_patch'
    Journal.send(:include, JournalPatch)
    Mailer.send(:include, MailerPatch)
    # Ensure jobs are loaded
    Dir[File.expand_path("#{__dir__}/app/jobs/**/*.rb")].each { |f| require_dependency f }
  end

  settings default: {
    'enabled' => 'true',
    'delay' => '5'
  }, partial: 'settings/batched_notifications_settings'
end


