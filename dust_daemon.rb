require 'serialport'
require 'net/http'
require 'parseconfig'

XBEE_PORT_DEV = "/dev/tty.usbserial-AH01DH9Y"
#XBEE_PORT_DEV = "/dev/tty.PL2303-00001004"
XBEE_PORT_PARAMS = {'baud' => 38400, 'data_bits' => 8, 'stop_bits' => 1, 'parity' => SerialPort::NONE}

@config = ParseConfig.new('./db/dust.config')

def send_data(dc1100_string)
    uri = URI(@config['data_url'])
    req = Net::HTTP::Post.new(uri.path)
    req.set_form_data('measured_at' => Time.now.to_i, 'data' => dc1100_string)
    req.basic_auth @config['username'], @config['password']

    res = Net::HTTP.start(uri.hostname, uri.port) {|http|
       http.request(req)
    }

    if res.is_a?(Net::HTTPSuccess)
    else
        puts "#{Time.now.to_s}: ERROR sending request to #{DATA_URL}: #{res.inspect}"
    end
end

#{"d1":5989,"d2":136,"t1":25,"h1":58,"rc":1,"pc":96,"ts":194250,"hs":0}
def main_loop
    SerialPort.open(XBEE_PORT_DEV, XBEE_PORT_PARAMS) { |sp|
        while sensors = sp.gets
            send_data(sensors.strip)
            puts "#{Time.now.to_s}: #{sensors}"
        end
    }
end

main_loop
