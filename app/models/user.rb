class User < ApplicationRecord
  # relationship
  has_many :microposts, dependent: :destroy
  has_many :active_relationships, class_name: Relationship.name,
           foreign_key: "follower_id",
           dependent: :destroy
  has_many :passive_relationships, class_name: Relationship.name,
           foreign_key: "followed_id",
           dependent: :destroy
  has_many :following, through: :active_relationships, source: :followed
  has_many :followers, through: :passive_relationships, source: :follower

  # instant attributes
  attr_accessor :remember_token, :activation_token, :reset_token

  # call back
  before_create :create_activation_digest

  # validate
  before_save :downcase_email

  validates :name, presence: true,
            length: {maximum: Settings.validate.name.length.max}

  validates :email, presence: true,
            length: {maximum: Settings.validate.email.length.max},
            format: {with: Settings.validate.email.regex}, uniqueness: true

  validates :password, presence: true,
            length: {minimum: Settings.validate.password.length.min},
            allow_nil: true
  has_secure_password

  # class method
  class << self
    # Returns the hash digest of the given string.
    def digest string_param
      cost = if ActiveModel::SecurePassword.min_cost
               BCrypt::Engine::MIN_COST
             else
               BCrypt::Engine.cost
             end
      BCrypt::Password.create(string_param, cost:)
    end

    # Returns a random token
    def new_token
      SecureRandom.urlsafe_base64
    end
  end

  # instant method

  # Remembers a user in the database for use in persistent sessions.
  def remember
    self.remember_token = User.new_token
    update_column :remember_digest, User.digest(remember_digest)
    remember_digest
  end

  # Returns true if the given token matches the digest.
  def authenticated? attribute, token
    digest = __send__("#{attribute}_digest")
    return false unless digest

    BCrypt::Password.new(digest).is_password?(token)
  end

  # Forgets a user.
  def forget
    update_column :remember_digest, nil
  end

  # Returns a session token to prevent session hijacking.
  # We reuse the remember digest for convenience.
  def session_token
    remember_digest || remember
  end

  # Activates an account.
  def activate
    update_columns activated: true, activated_at: Time.zone.now
  end

  # Sends activation email.
  def send_activation_email
    UserMailer.account_activation(self).deliver_now
  end

  # Sets the password reset attributes.
  def create_reset_digest
    self.reset_token = User.new_token
    update_columns reset_digest: User.digest(reset_token),
                   reset_sent_at: Time.zone.now
  end

  # Sends password reset email.
  def send_password_reset_email
    UserMailer.password_reset(self).deliver_now
  end

  # Returns true if a password reset has expired.
  def password_reset_expired?
    reset_sent_at < 2.hours.ago
  end

  # Defines a proto-feed.
  # Returns a user's status feed.
  def feed
    Micropost.feed id
  end

  # Follows a user.
  def follow other_user
    following << other_user unless self == other_user
  end

  # Unfollows a user.
  def unfollow other_user
    following.delete other_user
  end

  # Returns true if the current user is following the other user.
  def following? other_user
    following.include? other_user
  end

  # private methods

  private

  def downcase_email
    email.downcase!
  end

  # Creates and assigns the activation token and digest.
  def create_activation_digest
    self.activation_token = User.new_token
    self.activation_digest = User.digest(activation_token)
  end
end
