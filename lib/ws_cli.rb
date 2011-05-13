
if !defined? MyTimer
begin
  require 'system_timer'
  MyTimer = SystemTimer
rescue LoadError
  require 'timeout'
  MyTimer = Timeout
end
end

require 'socket'
require 'logger'
require 'ws_proto_hybi07'
require 'pp'


class WSClient
  def initialize(logger, options)
    @logger = logger
    @host = options.delete(:host)
    @port = options.delete(:port)
    @timeout = options.delete(:timeout) || 40
    @version = options.delete(:proto) || :hybi07
    @proto = ProtoHybi07.new(@logger, options)
    @extensions = []

  end
  
  def connect(url, protocols=[])
    # make a handshake and send it to the server
    handshake = @proto.make_handshake(@host, protocols, @extensions)
    write_to_socket(handshake)
    headers = read_http_headers
    @proto.check_handshake_response(headers)
    return true
  end
  
  def connect_raw(data)
    write_to_socket(data)
  end
  
  def read_raw
    @sock.read
  end
  
  def read_data
    @proto.read_data(@sock)
  end
  
  def write_data(data, frame_size=nil)
    @proto.send_text_data(@sock, data, frame_size)
  end
  
  def ping(text)
    @proto.ping(@sock, text)
  end
  
  def close(code=nil, message=nil)
    ret = @proto.close_connection(@sock, code, message)
    @sock.close
    return ret
  end
  
  private
  
  def read_http_headers
    headers = []
    begin
      line = @sock.readline.chomp
#      puts "[#{line}] #{line.size}"
      headers << line if line.size > 0
    end while line != ""
    headers
  end
      
  def with_sock
    begin  
      MyTimer.timeout(@timeout) do
        connect_i if @sock.nil?
        yield @sock
      end
    rescue Exception => e
      @sock.close if @sock
      @sock = nil      
      return nil if e.is_a?(Timeout::Error)
      @logger.error("exception #{e.message}") 
      return nil
    end
  end

  def connect_to(host, port, timeout=nil)
    puts 
    @logger.debug("host #{host} port #{port}") 
    addr = Socket.getaddrinfo(host, nil)
    sock = Socket.new(Socket.const_get(addr[0][0]), Socket::SOCK_STREAM, 0)    

    if timeout
      secs   = Integer(timeout)
      usecs  = Integer((timeout - secs) * 1_000_000)
      optval = [secs, usecs].pack("l_2")
      sock.setsockopt Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, optval
      sock.setsockopt Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, optval
    end 
    sock.connect(Socket.pack_sockaddr_in(port, addr[0][3]))
    sock
  end  
  
  def connect_i
    @sock = connect_to(@host, @port, @timeout == 0 ? nil : @timeout)    
  end
  
  def read_from_socket
    @sock.read
  end

  def write_to_socket(cmd)
    begin
      connect_i if @sock.nil?
      MyTimer.timeout(2) do
        @sock.write(cmd)
      end
    rescue Exception => e
      @logger.error("exception #{e.message}") 
      @sock.close if @sock
      @sock = nil      
      return nil
    end    
    return true
  end  
  
  
end