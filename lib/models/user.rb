# == Schema Information
# Schema version: 20100205183625
#
# Table name: users
#
#  id            :integer(4)      not null, primary key
#  username      :string(255)     not null
#  name          :string(255)     default(""), not null
#  password_hash :string(255)     default(""), not null
#  password_salt :string(255)     default(""), not null
#  phone         :string(255)
#  last_login    :datetime
#  role_id       :integer(4)      default(1), not null
#  language      :string(255)     default("pt"), not null
#  timezone      :string(255)     default("Harare"), not null
#  advanced      :boolean(1)      default(FALSE), not null
#

class User < ActiveRecord::Base
  include BasicModelSecurity
#  attr_accessor :password_hash_confirmation
  referenced_by :name, :username

  has_one :street_address, :as => 'addressed'
  
  validates_presence_of :username
  validates_presence_of :role_id
  validates_presence_of :language
  validates_presence_of :timezone
  
  validates_uniqueness_of :username
  validates_uniqueness_of :phone, :allow_nil => true

  validates_format_of :phone, :with => /^\d+$/, :message => 'must be only digits', :allow_nil => true
  
  validates_confirmation_of :password_hash

  belongs_to :role

  has_and_belongs_to_many :delivery_zones
  has_and_belongs_to_many :administrative_areas
  has_and_belongs_to_many :health_centers
  named_scope :field_coordinators, { :joins => 'INNER JOIN roles ON users.role_id = roles.id', :conditions => [ 'roles.code = ?', 'field_coordinator' ], :order => :name }

  def delivery_zone
    delivery_zones.first
  end

  include Comparable
  def <=>(other)
    name <=> other.name
  end
  
  def self.admin
    User.find_by_username('admin') #boo
  end

  def primary_admin?
    username == 'admin'
  end
  
  def districts
    responsible_health_centers.map(&:district).uniq
  end
  
  def default_vehicle_code
    ''
  end
  
  def phone=(p)
    super(p.blank? ? nil : p)
  end
  
  def provinces
    administrative_areas.select { |a| a.is_a?(Province)}
  end

  def self.options_for_select
    all(:order => 'name').map { |f| [f.name, f.id] }
  end

  # UNUSED
  # def responsible_for?(area)
  #   maybe(delivery_zone) { |dz| dz.health_center_catchments.include?(area) } ||
  #     provinces.include?(area.province)
  # end

  def responsible_health_centers(*args)
    if field_coordinator?
      delivery_zone.maybe.health_centers(*args)
    elsif manager?
      delivery_zones = DeliveryZone.all unless delivery_zones.present?
      delivery_zones.map(&:health_centers).flatten
    else 
      []
    end
  end

  def admin?
    role_code == 'admin'
  end

  def manager?
    role_code == 'manager'
  end

  def field_coordinator?
    role_code == 'field_coordinator'
  end

  def can_edit?
    admin? || manager?
  end

  def self.authenticate(username, password)
    u = find_by_username(username)

    if !u.nil? && u.hashed_password(password) == u[:password_hash]
      return u
    else
      return nil
    end
  end

  def password_confirmation=(p)
    self.password_hash_confirmation = hash_password(p) unless p.blank?
  end

  def password_confirmation
    ''
  end

  def password=(p)
    self.password_hash = p unless p.blank?
  end

  def password
    ''
  end

  def password_hash=(p)
    unless p.blank?
      super(hash_password(p))
      self.password_hash_confirmation ||= ''
    end
  end

  require 'digest/sha1'
  def random_string
    Digest::SHA1.hexdigest(rand().to_s + rand().to_s + rand().to_s) 
  end

  def hashed_password(p)
    Digest::SHA1.hexdigest("#{password_salt}--#{p}--")
  end

  def role_name
    role.label if role
  end
  
  private

  def hash_password(p)
    @salt ||= random_string
    self.password_salt = @salt
    hashed_password(p)
  end
end


