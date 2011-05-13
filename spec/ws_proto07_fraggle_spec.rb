
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
  
  it "should pass test with fraggle-protocol" do
    @c.connect('/test', ['fraggle-protocol']).should be_true
    resp = @c.read_data
    # calculate checksum
    sum = 0
    resp.each_byte do |b|
      sum += b
    end
    ch = @c.read_data
    checksum = ch.unpack('N*')[0]    
    (checksum == sum).should be_true
    @c.close.should be_true
  end  

end  
