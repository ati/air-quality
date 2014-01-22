# encoding: utf-8
require 'prowler'
require 'ruby-notify-my-android'

class Prowl < Sequel::Model
  plugin :after_initialize

  APP_NAME = 'vozduh.msk.ru'
  NMA_API_KEY_LENGTH = 48

  @notifier = nil

  def after_initialize
    @notifier = api_key.length.eql?(NMA_API_KEY_LENGTH) ? NMA : Prowler
    if @notifier.eql?(Prowler)
      Prowler.verify_certificate = false
    end
  end

  def validate
    super
    begin
      @notifier.eql?(Prowler) ? 
        Prowler.new(application: APP_NAME, api_key: api_key).verify :
        NMA.valid_key?(api_key)

    rescue Exception => e
      LOGGER.error(e.message)
      LOGGER.error(e.backtrace.inspect)
      errors.add(:api_key, 3)
      return false
    end
  end

  def do_send_nma(nma_event, nma_description)
	NMA.notify do |n| 
	  n.apikey = api_key # can also be list such as ["key1", "key2"]
	  n.priority = NMA::Priority::MODERATE
	  n.application = APP_NAME
	  n.event = nma_event
	  n.description = nma_description
	end
  end

  def notify(facility, message)
    raise "undefined notifier" if @notifier.is_a?(NilClass)
	facility_name = { rain: 'Дождь', dust: 'Пыль'}

      if @notifier.eql?(Prowler)
		puts("sending Prowler notification")
        Prowler.new(application: APP_NAME, api_key: api_key).notify(facility_name[facility], message)
      else
		puts("sending NMA notification: api_key=#{api_key}, application=#{APP_NAME}, event=#{facility_name[facility]}, message=#{message}")
		do_send_nma(facility_name[facility], message)
#        NMA.notify do |n|
#          n.apikey = api_key,
#          n.priority = NMA::Priority::MODERATE
#          n.application = APP_NAME
#          n.event = facility_name[facility]
#          n.description = message
#        end
      end
      # ts_key = "#{facility}_at".to_s
      #self.update(ts_key => Time.now)
  end


end
