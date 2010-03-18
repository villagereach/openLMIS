  map.mini_table '/:path/render_mini_table', :action => 'render_mini_table', :controller => :olmis

  map.resources :users, :member => { :profile => [:get, :put] }

  map.new_fridge_status '/fridge_statuses/new', :controller => :fridge_statuses, :action => 'create', :conditions => { :method => [:put, :post] }
  
  map.resources :fridges, :path_prefix => 'cold_chain'
  map.resources :health_centers, :has_many => [:fridges, :street_addresses]

  map.health_center_cold_chain '/cold_chain/:health_center', :controller => 'cold_chain', :action => 'location'
  map.cold_chain '/cold_chain', :controller => 'cold_chain', :action => 'index'

  map.fc_visits          '/fcs',                  :controller => 'field_coordinators', :action => 'index', :method => :get
  map.fc_visits_by_month '/fcs/:visit_month',     :controller => 'field_coordinators', :action => 'index', :method => :get
  map.fc                 '/fcs/:id/:visit_month', :controller => 'field_coordinators', :action => 'show',  :method => :get

  map.isa '/pickups/:delivery_zone/isa/:health_center', :controller => 'pickups', :action => 'isa_edit'
  map.isa_redirect '/pickups/:delivery_zone/isa_redirect', :controller=>'pickups', :action => 'isa_redirect'

  map.pickup_new '/pickups/:delivery_zone/new', :controller => 'pickups', :action => 'pickup_new'
  map.pickup_edit '/pickups/:delivery_zone/:date/edit', :controller => 'pickups', :action => 'pickup_edit'
  map.pickup '/pickups/:delivery_zone/:date', :controller => 'pickups', :action => 'pickup'
  map.pickups '/pickups/:delivery_zone', :controller => 'pickups', :action => 'pickups'

  map.unload_new '/unloads/:delivery_zone/new', :controller => 'pickups', :action => 'unload_new'
  map.unload_edit '/unloads/:delivery_zone/:date/edit', :controller => 'pickups', :action => 'unload_edit'
  map.unload '/unloads/:delivery_zone/:date', :controller => 'pickups', :action => 'unload'
  map.unloads '/unloads/:delivery_zone', :controller => 'pickups', :action => 'unloads'
  
  map.connect '/set_date_period', :controller=>'dashboard', :action=>'set_date_period'
  map.login   '/login',  :controller => 'login', :action => 'login'
  map.logout  '/logout', :controller => 'login', :action => 'logout'
  map.is_logged_in '/logged-in', :controller => 'olmis', :action => 'logged_in'
  
  map.connect '/graph_data/:graph.:format', :controller => 'graph_data', :action => 'graph'
 
  map.connect '/config',  :controller => 'dashboard', :action => 'config'

  map.visits                  '/visits', :controller => 'visits', :action => 'index', :method => :get
  map.visits_search           '/visits/search', :controller => 'visits', :action => 'search', :method => :get
  map.visits_search_auto_complete 'visits/auto_complete_for_health_center_name', :controller => 'visits', :action => 'auto_complete_for_health_center_name', :conditions => { :method => :get }
  map.visits_by_month         '/visits/:visit_month', :controller => 'visits', :action => 'by_month', :method => :get
  map.health_center_visit     '/visits/:visit_month/:health_center', :controller => 'visits', :action => 'health_center_monthly_visit'
  map.health_center_visit_title '/visits/:visit_month/:health_center/title', :controller => 'visits', :action => 'health_center_monthly_visit_title'
  map.health_center_visit_format '/visits/:visit_month/:health_center.:format', :controller => 'visits', :action => 'health_center_monthly_visit'
  map.health_center_adult_epi '/visits/:visit_month/:health_center/epi/adult', :controller => 'visits', :action => 'health_center_tally', :tally => 'AdultVaccinationTally'
  map.health_center_child_epi '/visits/:visit_month/:health_center/epi/child', :controller => 'visits', :action => 'health_center_tally', :tally => 'ChildVaccinationTally'
  map.health_center_full_epi  '/visits/:visit_month/:health_center/epi/full',  :controller => 'visits', :action => 'health_center_tally', :tally => 'FullVaccinationTally'
  map.health_center_rdt_epi  '/visits/:visit_month/:health_center/epi/rdt',    :controller => 'visits', :action => 'health_center_tally', :tally => 'RdtTally'
  map.health_center_usage_epi '/visits/:visit_month/:health_center/epi/usage',  :controller => 'visits', :action => 'health_center_tally', :tally => 'EpiUsageTally'

  map.nuke_caches             '/nuke_caches', :controller => 'olmis', :action => 'nuke_caches'

  map.health_center_equipment_general   '/visits/:visit_month/:health_center/equipment/general',   :controller => 'visits', :action => 'health_center_equipment'
  map.health_center_equipment_coldchain '/visits/:visit_month/:health_center/equipment/coldchain', :controller => 'visits', :action => 'health_center_cold_chain'
  map.health_center_equipment_stockcards '/visits/:visit_month/:health_center/equipment/stockcards', :controller => 'visits', :action => 'health_center_stock_cards'

  map.health_center_inventory '/visits/:visit_month/:health_center/inventory', :controller => 'visits', :action => 'health_center_inventory'

  map.root :controller => 'dashboard', :action => 'homepage'

  map.reports '/reports', :controller => 'reports', :action => 'index'
  map.report_maps '/reports/:action', :controller => 'reports'

  map.delivery_zone_selector '/dz', :controller => 'olmis', :action => 'delivery_zone_selector'
  map.district_selector      '/dct', :controller => 'olmis', :action => 'district_selector'



  ## Catch-all route for auto_complete actions (could be useful if there is a proliferation of auto-complete actions)
  #map.auto_complete ':controller/:action', :action => /auto_complete_for_\S+/, :conditions => { :method => :get }

