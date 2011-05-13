
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
  
  it "should support get version via ws-test protocol" do
    @c.connect('/test').should be_true
    resp = @c.read_data
    (resp == 'connected,').should be_true
    str1 = "version,"
    @c.write_data(str1)
    resp = @c.read_data
    # calculate checksum
    ('version,hybi-draft-07' == resp).should be_true
    @c.close.should be_true        
  end  
  
  it "should support echo test via ws-test protocol" do
    @c.connect('/test').should be_true
    resp = @c.read_data
    (resp == 'connected,').should be_true
    str1 = "echo,test"
    @c.write_data(str1)
    resp = @c.read_data
    # check response
    (str1 == resp).should be_true
    @c.close.should be_true    
  end  
    
  it "should support fragmentation test via ws-test protocol" do
    @c.connect('/test').should be_true
    resp = @c.read_data
    (resp == 'connected,').should be_true
    count = 512
    str = (0...count).map{65.+(rand(25)).chr}.join    
    str1 = "fragments,"+str
    @c.write_data(str1)
    resp = @c.read_data
    # check server response
    (str1 == resp).should be_true
    @c.close.should be_true
  end
  
  it "should support ping via ws-test protocol" do
    @c.connect('/test').should be_true
    resp = @c.read_data
    (resp == 'connected,').should be_true
    str1 = "ping,"
    @c.write_data(str1)
    # call read to trigger sending pong response
    resp = @c.read_data
    # read protocol response
    resp = @c.read_data
    # calculate checksum
    ('ping,success' == resp).should be_true
    @c.close.should be_true        
  end
  

end  
