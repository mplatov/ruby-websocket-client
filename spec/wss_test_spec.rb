
require 'ws_cli'

host = 'wss.websocketstest.com'
port = 443
proto = :hybi07

describe WSClient do
  
  before :each do
    log = Logger.new(STDOUT)
#    log.level = Logger::DEBUG
    log.level = Logger::ERROR
    @c = WSClient.new(log, {:host => host, :port => port, :proto => proto, :frame_compression => true, :secure => true})
  end
  
  it "should connect with SSL" do
    @c.connect('/test', ['org.ietf.websocket.test-echo-fragment'])
    str ="test 1234567890 test 1234567890"
    @c.write_data(str)
    (@c.read_data == str).should be_true
  end

end