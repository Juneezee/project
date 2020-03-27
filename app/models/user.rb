# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                         :bigint           not null, primary key
#  admin                      :boolean          default(FALSE)
#  birthdate                  :date
#  email                      :string           default(""), not null
#  encrypted_password         :string           default(""), not null
#  name                       :string           default(""), not null
#  password_automatically_set :boolean          default(FALSE), not null
#  remember_created_at        :datetime
#  reset_password_sent_at     :datetime
#  reset_password_token       :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#

# User model
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[google_oauth2 twitter facebook]

  has_one_attached :avatar
  has_one :license, dependent: :destroy

  has_many :identities, dependent: :destroy
  has_one :user_personality, dependent: :destroy
  has_one :personality, through: :user_personality
  has_many :preferences, dependent: :destroy
  has_many :skill_levels, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :tasks, dependent: :destroy
  # has_and_belongs_to_many :teams
  has_many :reviews, dependent: :destroy

  validates :email,
            presence: true,
            uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :avatar, content_type: %w[image/png image/jpg image/jpeg],
                     size: { less_than: 200.kilobytes }

  validate :provided_birthdate, on: :update

  before_commit :create_license, on: :create

  after_commit :disable_password_automatically_set,
               on: :update,
               if: :saved_change_to_encrypted_password?

  def self.sign_in_omniauth(auth)
    Identity.where(provider: auth.provider, uid: auth.uid).first_or_create(
      user: create(
        email: auth.info.email,
        name: auth.info.name,
        password: Devise.friendly_token[0, 20],
        password_automatically_set: true
      )
    )
  end

  def self.connect_omniauth(auth, current_user)
    Identity.create(provider: auth.provider, uid: auth.uid, user: current_user)
  end

  def oauth_provider_connected?(provider = nil)
    identities.where(provider: provider).present?
  end

  def newsletter_subscribed?
    NewsletterSubscription.find_by(email: email)&.subscribed?
  end

  private

  def create_license
    super
  end

  def disable_password_automatically_set
    return unless password_automatically_set

    update(password_automatically_set: false)
  end

  def provided_birthdate
    return if birthdate_before_type_cast.blank?

    date = Date.new(
      birthdate_before_type_cast[1], # year
      birthdate_before_type_cast[2], # month
      birthdate_before_type_cast[3]  # day of month
    )

    if date >= created_at.to_date
      errors.add(:birthdate, 'must be before the account creation date')
      return
    end

    age = ((Time.current - date.to_time) / 1.year.seconds).floor

    return if age.between?(6, 80)

    errors.add(:age, 'must be between 6 and 80 years old')
  rescue StandardError
    errors.add(:date, 'is invalid')
  end

end
