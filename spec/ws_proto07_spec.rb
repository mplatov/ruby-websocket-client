
require 'ws_cli'

host = 'ws.websocketstest.com'
port = 8080
proto = :hybi07

describe WSClient do
  before :each do
    @log = Logger.new(STDOUT)
#    log.level = Logger::DEBUG
    @log.level = Logger::ERROR
    @c = WSClient.new(@log, {:host => host, :port => port, :proto => proto, :frame_compression => true})
  end
  
  it "should connect to a server using mirror protocol" do
    @c.connect('/test', ['lws-mirror-protocol']).should be_true
    @c.close.should be_true
  end
  
  it "should support sending close message with a custom close payload" do
    @c.connect('/test', ['lws-mirror-protocol']).should be_true
    @c.close(1000, "normal close").should be_true
  end
  
  it "should receive the data with lws-mirror-protocol" do
    str ="test 1234567890 test 1234567890"
    @c.connect('/test', ['lws-mirror-protocol']).should be_true
    @c.write_data(str)
    (str == @c.read_data).should be_true
    @c.close.should be_true
  end
  
  it "should support sending frames with the size of more that 125 bytes" do
    count = rand(3500) + 125
    str = (0...count).map{65.+(rand(25)).chr}.join
    @c.connect('/test', ['lws-mirror-protocol']).should be_true
    @c.write_data(str)
    (str == @c.read_data).should be_true    
    @c.close.should be_true
  end
  
  it "should support sending frames with the size of more than 65535 bytes" do
    count = rand(5000) + 65535
    str = (0...count).map{65.+(rand(25)).chr}.join
    @c.connect('/test', ['lws-mirror-protocol']).should be_true
    @c.write_data(str)
    resp = @c.read_data
    (str == resp ).should be_true        
    @c.close.should be_true
  end
    
  
  it "should support sending messages with the size of more that 125 bytes split into several fragments" do
    count = rand(3500) + 125
    frame_size = rand(500) + 100
    str = (0...count).map{65.+(rand(25)).chr}.join
    @c.connect('/test', ['lws-mirror-protocol']).should be_true
    @c.write_data(str, frame_size)
    (str == @c.read_data).should be_true        
    @c.close.should be_true
  end
  
  it "should support sending messages with the size of more that 65535 bytes split into several fragments" do
    count = rand(100000) + 65535 + 100000
    frame_size = rand(500) + 65535
    str = (0...count).map{65.+(rand(25)).chr}.join
    @c.connect('/test', ['lws-mirror-protocol']).should be_true
    @c.write_data(str, frame_size)
    (str == @c.read_data).should be_true            
    @c.close.should be_true
  end
  
    
  it "should support sending data with multiple frames" do
    str ="test 1234567890 test 1234567890"
    @c.connect('/test', ['lws-mirror-protocol']).should be_true
    @c.write_data(str, 10)
    (str == @c.read_data).should be_true    
    @c.close.should be_true
  end
  
  it "should support ping messages" do
    @c.connect('/test', ['lws-mirror-protocol']).should be_true
    @c.ping("ksjahdfjkhsadkf").should be_true
    @c.close.should be_true
  end
  
  it "should report an error on attempt to connect with unsupported version of the protocol" do
    @c.connect_raw("GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Origin: localhost\r\nSec-WebSocket-Version: 70\r\nSec-WebSocket-Protocol: lws-mirror-protocol\r\n\r\n")
    @c.read_raw.strip.should == "HTTP/1.0 400 Bad Request"
  end
    
  it "should close connection on receiving a client message with no masking" do
    c = WSClient.new(@log, {:host => host, :port => port, :proto => proto, :frame_compression => true, :masking_disabled => true})
    str ="test 1234567890 test 1234567890"
    c.connect('/test', ['lws-mirror-protocol']).should be_true
    c.write_data(str)
    c.read_data.should raise_error
    c.close.should be_true    
  end
  
end
