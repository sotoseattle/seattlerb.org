class Member < ActiveRecord::Base
  habtm :projects, :join_table => :affiliations

  validates_presence_of :name, :email
  # our migrations are so stupid. If we nuke the data, this conditional can go
  validates_presence_of :ruby_gems_id, :if => proc { |u| u.respond_to? :ruby_gems_id }

  validates :email, email: true, :uniqueness => true, :allow_blank => true
  validates :github, github: true, :allow_blank => true
  validates :ruby_gems_id, rubygems: true, :allow_blank => true
  validates :website, url: true, :allow_blank => true

  scope :featured, where(featured: true)
  scope :regular, where(featured: false)

  before_save :set_avatar, if: Proc.new { |user|
    user.respond_to?(:twitter_changed?) and user.twitter_changed?
  }

  before_save :set_github
  before_save :set_rubygems

  def set_rubygems
    rubygems_username = self['ruby_gems_id']
    unless rubygems_username.empty?
      self['ruby_gems_id'] = "http://rubygems.org/profiles/#{rubygems_username}"
    end
  end

  def set_github
    github_username = self['github']
    unless github_username.empty?
      self['github'] = "https://github.com/#{github_username}"
    end
  end

  def bio
    bio = self['bio']
    bio.present? ? bio : "..."
  end

  def update_avatar!
    set_avatar
    save
  end

  def set_avatar
    if missing_image? && !self.image_url.nil?
      twitter_response = get_twitter_image_url if twitter
      image_url = if twitter_response
        twitter_response.to_s
      else
        "missing_image.png"
      end
      self.image_url = image_url
    else
      self.image_url = "missing_image.png"
    end
  end

  def missing_image?
    image_url.blank? || image_url == "missing_image.png" || HTTParty.get(self.image_url).code != 200
  end

  def get_twitter_image_url
    client = Twitter::REST::Client.new do |config|
      config.consumer_key = ENV['TWITTER_CONSUMER_KEY']
      config.consumer_secret = ENV['TWITTER_CONSUMER_SECRET']
      config.access_token = ENV['TWITTER_ACCESS_TOKEN']
      config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
    end

    client.user(self.twitter).profile_image_uri_https(:bigger).to_s
  end
end
