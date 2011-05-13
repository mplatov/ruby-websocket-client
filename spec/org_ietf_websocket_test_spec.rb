
require 'ws_cli'

host = 'ws.websocketstest.com'
port = 8080
proto = :hybi07

describe WSClient do
  
  before :each do
    log = Logger.new(STDOUT)
#    log.level = Logger::DEBUG
    log.level = Logger::ERROR
    @c = WSClient.new(log, {:host => host, :port => port, :proto => proto, :frame_compression => true})
  end
  
  it "should receive the data with org.ietf.websocket.test-produce protocol" do
    @c.connect('/test', ['org.ietf.websocket.test-produce']).should be_true
    res = @c.read_data
    @c.close.should be_true
  end

  it "should receive the data with org.ietf.websocket.test-echo protocol" do
    count = rand(3500) + 125
    str = (0...count).map{65.+(rand(25)).chr}.join
    @c.connect('/test', ['org.ietf.websocket.test-echo-fragment']).should be_true
    @c.write_data(str)
    (resp = @c.read_data).should be_true        
    (str == resp).should be_true
    @c.close.should be_true
  end

  it "should receive the data with org.ietf.websocket.test-echo protocol" do
    str = "test test test test test test test test test test test"
    @c.connect('/test', ['org.ietf.websocket.test-echo-fragment']).should be_true
    @c.write_data(str)
    (resp = @c.read_data).should be_true        
    (str == resp).should be_true
    @c.close.should be_true
  end

  it "should support org.ietf.websocket.test-echo-assemble protocol" do
    count = rand(3500) + 125
    str = (0...count).map{65.+(rand(25)).chr}.join
    @c.connect('/test', ['org.ietf.websocket.test-echo-fragment']).should be_true
    @c.write_data(str, 10)
    (resp = @c.read_data).should be_true        
    (str == resp).should be_true
    @c.close.should be_true
  end
  
  

end  
