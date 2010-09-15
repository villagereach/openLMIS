# == Schema Information
# Schema version: 20100419182754
#
# Table name: health_center_visits
#
#  id                     :integer(4)      not null, primary key
#  user_id                :integer(4)      not null
#  health_center_id       :integer(4)      not null
#  visit_month            :string(255)     not null
#  visited_at             :date            not null
#  vehicle_code           :string(255)     default(""), not null
#  visit_status           :string(255)     default("Visited"), not null
#  notes                  :text            default(""), not null
#  data_status            :string(255)     default("pending"), not null
#  epi_data_ready         :boolean(1)      default(TRUE), not null
#  created_at             :datetime
#  updated_at             :datetime
#  other_non_visit_reason :string(255)
#

class HealthCenterVisit < ActiveRecord::Base
  belongs_to :field_coordinator, :foreign_key => 'user_id', :class_name => 'User'
  belongs_to :health_center

  has_many :equipment_statuses
  has_many :stock_card_statuses
  
  has_many :health_center_visit_inventory_groups
  
  has_and_belongs_to_many :data_submissions, :order => 'created_at desc'
  
  validates_presence_of :user_id
  validates_presence_of :health_center_id
  validates_presence_of :visit_month
  validates_presence_of :visited_at
  #validates_presence_of :vehicle_code, :allow_blank => true
  validates_presence_of :visit_status
  validates_presence_of :other_non_visit_reason, :message => :describe_reason_for_not_visiting, :if => lambda{|r| r.visit_status == 'other'}
  validates_presence_of :data_status

  defaults :visit_status => 'Visited', :data_status => 'pending', 
    :vehicle_code => lambda { |r| r.field_coordinator ? r.field_coordinator.default_vehicle_code : '' }

  named_scope :recent, lambda{|count| { :order => 'updated_at DESC', :limit => count } }

  named_scope :by_user, lambda{|user| { :conditions => { :user_id => user } } }

  ExcusableNonVisitReasons = ['health_center_closed'] 

  # Get recent visit months (in descending order).
  #
  # The following options are recognized:
  # * <tt>:months</tt> - specifies the number of months for which visits will be checked
  # * <tt>:count</tt> - specifies the max number of visits to return
  # If both <tt>:months</tt> and <tt>:count</tt> are specified, the number of visit months returned
  # will not exceed the value of <tt>:months</tt>
  def self.recent_visit_months(options = {})
    sql_opts = { :select => "DISTINCT(visit_month)",:limit => options[:count], :order => "visit_month DESC" }
    sql_opts[:conditions] = [ "visit_month > ?", options[:months].months.ago(Date.today).to_date_period ] if options[:months]
    visit_months = find(:all, sql_opts).map(&:visit_month)
    visit_months = [Date.today.to_date_period] if visit_months.empty?
    return visit_months
  end

  def date_period
    visit_month
  end
  
  def validate
    if visit_status_changed?
      if @visited_status.blank? && @unvisited_status.blank?
        errors.add(:visited, 'set_visited')
      elsif !@visited_status.blank? && !@unvisited_status.blank?
        errors.add(:visited, 'visited_conflict')
      end
    end
    
    super
  end
  
  def event_log
    []
  end
  
  def self.depends_on_visit?
    false
  end
  
  def self.klass_by_screen
    @klass_by_screen ||= Hash[*(self.tables.map { |t| t.screens.map { |screen| [screen, t] } } + ['visit', self]).flatten]
  end
  
  def availability_class(task)
    if new_record?
      "preavailable"
    elsif !epi_data_ready && self.class.klass_by_screen[task] < ActsAsStatTally
      "unavailable"
    elsif !visited && [:inventory, :delivery, :general, :cold_chain, :stock_cards].include?(task)
      "unavailable"
    else
      "available"
    end
  end
  
  def visited
    visit_status == 'Visited'
  end
  
  def hour
    "12:00" #visited_at.strftime("%H:00")
  end
  
  def hour=(h)
    #self.visited_at = self.visited_at.to_date.to_time + h.to_i.hours
  end
  
  def date
    visited_at
  end

  def date=(d)
    self.visited_at = d if d #+ (visited_at ? visited_at.hour.hours : 0.hours) if d
  end
  
  def visited?
    visited
  end
  
  def visited=(v)
    v = (v.to_s != 'false')
    if v
      @visited_status = 'visited'
      self.visit_status = 'Visited'
    else
      @visited_status = ''
      self.visit_status = '' if @unvisited_status.blank?
    end
  end
  
  def reason_for_not_visiting=(r)
    if r.blank?
      @unvisited_status = ''
      self.visit_status = 'Visited'
    else
      self.visit_status = @unvisited_status = r
    end
  end
  
  def reason_for_not_visiting
    if visited then '' else visit_status end
  end
  
  def self.visited_options
    [[I18n.t('HealthCenterVisit.visited_yes'), true], [I18n.t('HealthCenterVisit.visited_no'), false]]
  end                   
  
  def self.unvisited_options
    ['road_problem', 'vehicle_problem', 'health_center_closed', 'other'].map { |c| [ I18n.t("HealthCenterVisit.#{c}"), c ] }
  end
  
  # Please do not ever refer to these by number.
  Statuses = [:REPORT_COMPLETE, :REPORT_INCOMPLETE, :REPORT_NOT_DONE, :REPORT_NOT_VISITED, :REPORT_IRRELEVANT]
  REPORT_COMPLETE =    :REPORT_COMPLETE
  REPORT_INCOMPLETE =  :REPORT_INCOMPLETE
  REPORT_NOT_DONE =    :REPORT_NOT_DONE
  REPORT_NOT_VISITED = :REPORT_NOT_VISITED
  REPORT_IRRELEVANT =  :REPORT_IRRELEVANT
  
  # Return a hash of values consisting of the status for each visit batch element
  #   (existing inventory, delivered inventory, general equipment, cold chain equipment, stock card equipment,
  #   EPI usage, Adult vaccinations, Child vaccinations, Full vaccinations, and RDTs reports).

  def status_by_screen_with_visit
    reports_status = status_by_screen
    reports_status['visit'] = new_record? ? REPORT_NOT_DONE : REPORT_COMPLETE
    reports_status
  end
  
  def progress_numbers(return_parts=true)
    required = status_by_screen_with_visit.reject{ |k,v| [REPORT_NOT_VISITED, REPORT_IRRELEVANT].include?(v) }.size
    done = status_by_screen_with_visit.reject{ |k,v| v != REPORT_COMPLETE }.size
    percent = (done * 100) / required
    return_parts ? [done, required, percent] : percent
  end

  def progress_percent
    progress_numbers(false)
  end

  def self.tables
    Olmis.tally_klasses + [Inventory, EquipmentStatus, FridgeStatus, StockCardStatus] + Olmis.additional_visit_klasses
  end

  def self.screens
    Olmis.configuration['visit_screens']
  end

  def self.empty_json
    '{}'
  end

  def self.xforms_group_name
    'health_center_visit'
  end

  def entry_counts=(c)
    @counts = c
  end
  
  def status_by_screen(screen=nil)
    @status ||= returning ActiveSupport::OrderedHash.new do |h|
      statuses = @counts || HealthCenterVisitPeriodicProgress.new.counts_by_health_center_visit_for_date_period([visit_month], [id])[id]

      self.class.screens.each do |s|
        if HealthCenterVisit.klass_by_screen[s].depends_on_visit? && !visited?
          h[s] = REPORT_NOT_VISITED
        else
          expected, entries = *statuses[s]
          h[s] = reporting_status_field(expected, entries)
        end
      end
    end

    screen.nil? ? @status : @status[screen]    
  end

  def overall_status
    st = status_by_screen_with_visit.values.reject{|v| v == REPORT_NOT_VISITED || v == REPORT_IRRELEVANT}.uniq
    return st.first if st.length == 1
    return REPORT_INCOMPLETE
  end

  def first_unvisited_screen
    status_by_screen.detect{|k,v| [REPORT_INCOMPLETE, REPORT_NOT_DONE].include?(v)}.maybe.first
  end
  
  private

  def reporting_status_field(expected_entries, entries)
    if expected_entries == 0
      REPORT_IRRELEVANT
    elsif entries && entries >= expected_entries
      REPORT_COMPLETE
    elsif entries.to_i == 0
      REPORT_NOT_DONE
    else
      REPORT_INCOMPLETE
    end
  end

  def combined_status(*values)
    [ REPORT_NOT_VISITED, REPORT_NOT_DONE, REPORT_COMPLETE ].each do |status|
      return status if values.all?{|v| v == status }
    end
    REPORT_INCOMPLETE
  end

  public
  
  def to_json
    ([self.class] + self.class.tables).inject({}) { |hash, table| 
      hash[table.table_name.singularize] = table.visit_json(self)
      hash
    }.to_json
  end
  
  def epi_month
    if !visit_month.blank?
      year, month = visit_month.split('-', 2)
      if month == '01'
        "%04d-%s" % [year.to_i - 1, '12']
      else
        "%s-%02d" % [year, month.to_i - 1]
      end
    end
  end

  def after_save
    find_or_initialize_inventory_records.each(&:save) if visited?
  end

  def ideal_stock
    inventories = find_or_initialize_inventory_records

    Hash[*inventories.map { |i| [i.inventory_type, i.package_counts_by_package_code] }.flatten].merge(
      {
        :ideal => health_center \
                    ? IdealStockAmount.all(
                        :conditions => { :stock_room_id => health_center.stock_room.id },
                        :include => :package
                      ).inject({}){ |h, isa| h[isa.package.code] = isa ; h } \
                    : nil
      })
  end

  def find_or_initialize_equipment_statuses()
    EquipmentType.active.sort.collect{|type| 
      EquipmentStatus.find_or_initialize_by_equipment_type_id_and_stock_room_id_and_health_center_visit_id(
        type.id,
        self.health_center ? self.health_center.stock_room.id : nil,
        self.id) }
  end
  
  def find_or_initialize_fridge_statuses(options = {})
    stock_room = health_center ? health_center.stock_room : nil 
    reported_at = visited_at
    
    statuses = reported_at ? 
      FridgeStatus.find_all_by_stock_room_id_and_reported_at(stock_room, visited_at.beginning_of_day..visited_at.end_of_day) :
      []
    status_fridges = statuses.map(&:fridge)
    hc_fridges = health_center ? health_center.stock_room.fridges.all : []
    
    statuses += (hc_fridges - status_fridges).map do |fridge|
      FridgeStatus.new(:reported_at => reported_at, :fridge => fridge, :stock_room => stock_room, :user_id => user_id)
    end

    while options[:min_count] && statuses.length < options[:min_count] 
      statuses << FridgeStatus.new(:reported_at => reported_at, :stock_room => stock_room, :user_id => user_id)
    end

    statuses.sort
  end    
  
  def find_or_initialize_stock_card_statuses
    @stock_card_statuses ||= begin
      scs = self.stock_card_statuses
      extra = StockCard.active.sort - scs.map(&:stock_card)
      scs + extra.collect{ |stock_card|
        StockCardStatus.new(
          :stock_card => stock_card,
          :stock_room => self.health_center ? self.health_center.stock_room : nil,
          :health_center_visit => self) 
        }
    end
  end

  def find_or_create_inventory_records
    find_or_initialize_inventory_records.each { |record| record.save if record.new_record? }
  end

  def find_or_initialize_inventory_records
    @inventory ||= Inventory.types.map { |t|
      Inventory.find_or_initialize_by_date_and_stock_room_id_and_inventory_type(
          self.visited_at ? self.visited_at.to_date : Date.today,
          self.health_center ? self.health_center.stock_room.id : nil,
          t).tap { |i| i.user_id ||= self.user_id }
    }
  end
  
  def self.visit_json(visit)
    { 'visited'                => visit.visited.to_s, 
      'non_visit_reason'       => visit.reason_for_not_visiting || 'other',
      'visited_at'             => visit.visited_at ? visit.visited_at.strftime("%Y-%m-%d") : '',
      'notes'                  => visit.notes || '',
      'other_non_visit_reason' => visit.other_non_visit_reason || '',
      'vehicle_id'             => visit.vehicle_code || '',
    }
  end
end


