require 'sequel'
require 'serialport'

XBEE_PORT_DEV = "/dev/tty.usbserial-AH01DH9Y"
#XBEE_PORT_DEV = "/dev/tty.PL2303-00001004"
XBEE_PORT_PARAMS = {'baud' => 38400, 'data_bits' => 8, 'stop_bits' => 1, 'parity' => SerialPort::NONE}

def setup

end
#"{\"d1\":5989,\"d2\":136,\"t1\":25,\"h1\":58,\"rc\":1,\"pc\":96,\"ts\":194250,\"hs\":0}\r\n"}
def main_loop
    SerialPort.open(XBEE_PORT_DEV, XBEE_PORT_PARAMS) { |sp|
        while sensors = sp.gets
            #p sensors.strip
            p sensors
        end
    }
end

setup
main_loop
