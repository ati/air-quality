require 'sequel'
require 'serialport'

XBEE_PORT_DEV = "/dev/tty.usbserial-AH01DH9Y"
XBEE_PORT_PARAMS = {'baud' => 9600, 'data_bits' => 8, 'stop_bits' => 1, 'parity' => SerialPort::NONE}

def setup

end

def main_loop
    SerialPort.open(XBEE_PORT_DEV, XBEE_PORT_PARAMS) { |sp|
        while sensors = sp.gets
            p sensors.strip
        end
    }
end

setup
main_loop
