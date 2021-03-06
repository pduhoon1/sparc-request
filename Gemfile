source 'https://rubygems.org'

gem 'activerecord-import'
gem 'activerecord-session_store'
gem 'acts_as_list', :git => 'https://github.com/swanandp/acts_as_list.git'
gem 'acts-as-taggable-on'
gem 'audited', '~> 4.3'
gem 'axlsx', git: 'https://github.com/randym/axlsx', branch: 'master'
gem 'axlsx_rails'
gem 'bluecloth'
gem 'bootstrap-sass'
gem 'bootstrap-select-rails'
gem 'bootstrap3-datetimepicker-rails'
gem 'capistrano', '~> 3.9'
gem 'capistrano-bundler', require: false
gem 'capistrano-rvm', require: false
gem 'capistrano-rails', require: false
gem 'capistrano-passenger', require: false
gem 'capistrano3-delayed-job', '~> 1.0'
gem 'coffee-rails'
gem 'country_select'
gem 'curb', '~> 0.9.3'
gem 'delayed_job_active_record'
gem 'delayed_job'
gem 'devise', '~> 4.2'
gem 'dynamic_form'
gem 'execjs'
gem 'exception_notification'
gem 'filterrific', git: 'https://github.com/ayaman/filterrific.git'
gem 'gon', '~> 6.1'
gem 'grape', '0.7.0'
gem 'grape-entity', '~> 0.4.4'
gem 'grouped_validations', :git => 'https://github.com/jleonardw9/grouped_validations.git', branch: 'master'
gem 'gyoku'
gem 'haml'
gem 'hashie-forbidden_attributes'
gem 'httparty', '~> 0.13.7'
gem 'icalendar'
gem 'jquery_datepicker'
gem 'jquery-rails'
gem 'jbuilder', '~> 2.0'
gem 'json', '>= 1.8'
gem 'letter_opener'
gem 'momentjs-rails', '>= 2.8.1'
gem 'mysql2', '~> 0.4'
gem 'nested_form'
gem 'nested_form_fields'
gem 'newrelic_rpm'
gem 'nokogiri'
gem 'nori'
gem 'nprogress-rails'
gem 'net-ldap', '~> 0.16.0'
gem 'omniauth'
gem 'omniauth-shibboleth'
gem 'paperclip', '~> 5.2', '>= 5.2.1'
gem 'pdfkit'
gem 'prawn', '0.12.0'
gem 'premailer-rails'
gem 'rack-mini-profiler'
gem 'rails', '~> 5.1', '>= 5.1.5'
gem 'rails-html-sanitizer'
# Needed to used audited-activerecord w/ Rails 5
gem "rails-observers", github: 'rails/rails-observers'
gem 'redcarpet'
gem 'remotipart'
gem 'rest-client'
gem 'sanitized_data',  git: 'https://github.com/HSSC/sanitized_data.git'
gem 'rubyzip', '>= 1.2.1'
gem 'sass'
gem 'sass-rails'
gem 'savon', '~> 2.2.0'
gem 'simplecov', require: false, group: :test
gem 'therubyracer', '0.12.3', :platforms => :ruby, group: :production
gem 'twitter-typeahead-rails'
gem 'uglifier', '>= 1.0.3'
gem 'whenever', require: false
gem 'will_paginate'
gem 'will_paginate-bootstrap'
gem 'x-editable-rails'
gem 'omniauth-cas'
gem 'dotenv-rails'

group :development, :test, :profile do
  gem 'addressable', '~> 2.3.6'
  gem 'bullet'
  gem 'connection_pool'
  gem 'equivalent-xml'
  gem 'faker'
  gem 'launchy'
  gem 'timecop'
  gem 'progress_bar'
end
gem 'puma', '~> 3.0'

group :development, :test do
  gem 'pry'
  gem 'rails-erd'
  gem 'rspec-rails', '~> 3.4'
end

group :development do
  gem 'highline'
  gem 'spring-commands-rspec'
  gem 'byebug'
  gem 'spring'
  gem 'sqlite3'
  gem 'traceroute'
  gem 'parallel_tests', group: :development
end

group :test do
  gem 'capybara-webkit'
  gem 'database_cleaner'
  gem 'email_spec'
  gem 'factory_girl_rails'
  gem 'rails-controller-testing', require: false
  gem 'rspec-activemodel-mocks'
  gem 'rspec-html-matchers'
  gem 'shoulda-matchers', require: false
  gem 'shoulda-callback-matchers'
  gem 'site_prism'
  gem 'webmock'
end

group :assets do
  # We don't require this because we only have it so
  # that we can run asset precompile during build without
  # connecting to a database
  # If we allow it to be required though it will screw up
  # schema load / migrations because monkey patching.
  # So what we do is not require it and then generate the
  # require statement in the database.yml that we generate
  # in the hab package build
  gem "activerecord-nulldb-adapter", require: false
end

group :profile do
  gem 'ruby-prof'
end
