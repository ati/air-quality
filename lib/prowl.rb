# encoding: utf-8
require 'prowler'

class Prowl < Sequel::Model
  
  APP_NAME = 'vozduh.msk.ru'
  RAINS = %w(слабый средний сильный)

  def validate
    pr = Prowler.new(application: APP_NAME, apikey: api_key.to_s)
    Prowler.verify_certificate = false
    pr.verify('api_key')
  end

  def notify(facility, message)
    pr = Prowler.new(application: APP_NAME, api_key: api_key)
    Prowler.verify_certificate = false
    pr.notify(facility, message)
  end


end
