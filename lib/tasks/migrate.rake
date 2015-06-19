# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'csv'

namespace :migrate do

  namespace :user do

    desc "Migrate to User login field from display_name"
    task login_field: :environment do

      user_display_names = ENV['USERS'].try(:split, ",")
      validator = LoginUniquenessValidator.new

      null_login_users = User.where(login: nil)
      unless user_display_names.blank?
        display_name_scope = User.where(display_name: user_display_names)
        null_login_users = null_login_users.merge(display_name_scope)
      end

      total = null_login_users.count

      null_login_users.find_each.with_index do |user, index|
        puts "#{ index } / #{ total }" if index % 1_000 == 0
        sanitized_login = User.sanitize_login user.display_name

        user.login = sanitized_login
        counter = 0

        validator.validate user
        until user.errors[:login].empty?
          if user.errors[:login]
            user.login = "#{ sanitized_login }-#{ counter += 1 }"
          end

          user.errors[:login].clear
          validator.validate user
        end

        user.update_attribute :login, user.login
      end
    end

    desc "Migrate to User login field from display_name"
    task beta_email_communication: :environment do

      user_emails = CSV.read("#{Rails.root}/beta_users.txt").flatten!

      raise "Empty beta file list" if user_emails.blank?

      beta_users = User.where(beta_email_communication: nil, email: user_emails)
      beta_users_count = beta_users.count
      beta_users.update_all(beta_email_communication: true)
      puts "Updated #{ beta_users_count } users to receive emails for beta tests."
    end
  end
end