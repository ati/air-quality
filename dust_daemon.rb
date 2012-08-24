require 'serialport'
require 'net/http'
require 'parseconfig'
require 'json'

#XBEE_PORT_DEV = "/dev/tty.usbserial-AH01DH9Y"
#XBEE_PORT_DEV = "/dev/tty.PL2303-00001004"

XBEE_PORT_PARAMS = {'baud' => 38400, 'data_bits' => 8, 'stop_bits' => 1, 'parity' => SerialPort::NONE}

@config = ParseConfig.new(File.dirname(__FILE__) + '/db/dust.config')
STDOUT.sync = true


def make_request(uri,req)
    res = Net::HTTP.start(uri.hostname, uri.port) {|http|
       http.request(req)
    }

    if res.is_a?(Net::HTTPSuccess)
        return true
    else
        puts "#{Time.now.to_s}: ERROR sending request to #{uri.path}: #{res.inspect}"
        return false
    end
end


def send_data(dc1100_string)
    uri = URI(@config['data_url'])
    req = Net::HTTP::Post.new(uri.path)
    req.set_form_data('measured_at' => Time.now.to_i, 'data' => dc1100_string)
    req.basic_auth @config['username'], @config['password']
    
    make_request(uri, req)
end


#https://cosm.com/docs/quickstart/curl.html
def publish_cosm(dc1100_string)
    uri = URI(@config['cosm_url'])
    req = Net::HTTP::Put.new(uri.path)
    req['X-ApiKey'] = @config['cosm_key']
    data = JSON.parse(dc1100_string);
    req.body = {
        "version"   => "1.0.0",
        "datastreams"   => [
            {"id" => "PM2.5", "current_value" => data['d1']},
            {"id" => "PM10", "current_value"  => data['d2']},
            {"id" => "rain", "current_value"  => data['rc']},
        ]
    }.to_json
    puts req.inspect

    make_request(uri,req)
end


#{"d1":5989,"d2":136,"t1":25,"h1":58,"rc":1,"pc":96,"ts":194250,"hs":0}
def main_loop
    SerialPort.open(@config['xbee_device'], XBEE_PORT_PARAMS) { |sp|
        while sensors = sp.gets.strip
            send_data(sensors)
            publish_cosm(sensors)
            puts "#{Time.now.to_s}: #{sensors}"
        end
    }
end

main_loop
