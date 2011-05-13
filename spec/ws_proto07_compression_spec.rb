
require 'ws_cli'

host = '127.0.0.1'
port = 8001
proto = :hybi07

describe WSClient do
  
  before :each do
    log = Logger.new(STDOUT)
#    log.level = Logger::DEBUG
    log.level = Logger::ERROR
    @c = WSClient.new(log, {:host => host, :port => port, :proto => proto, :frame_compression => true})
  end
  
  it "should receive the data with lws-mirror-protocol" do
    str ="test0123455679 test0123455679 test0123455679"
    @c.connect('/test', ['lws-mirror-protocol']).should be_true
    @c.write_data(str)
    (resp = @c.read_data).should be_true
    @c.close.should be_true
  end
  
  

end  
