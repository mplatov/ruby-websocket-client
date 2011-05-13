
require 'zlib'
require "base64"
require 'digest/sha1'

class ProtoHybi07
  
  def initialize(logger, options)
    @logger = logger
    @compression = options.delete(:frame_compression)
    @origin = options.delete(:origin) || "localhost"
    @masking_disabled = options.delete(:masking_disabled)
  end
  
  def init
    @connected = false
    @close_received = false
    @close_sent = false
    @pong_received = false    
  end
        
  def make_handshake(host, protocols, extensions)
    init
    @handshake = make_handshake_key
    str = "GET / HTTP/1.1\r\n"
    str += "Host: #{host}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
    str += "Sec-WebSocket-Key: #{@handshake}\r\n"
    str += "Sec-WebSocket-Origin: #{@origin}\r\n"
    str += "Sec-WebSocket-Version: 7\r\n"
    
    if protocols and protocols.size > 0
      str += "Sec-WebSocket-Protocol: #{protocols.join(',')}\r\n"
    end
    
    if @compression
      extensions << "deflate-application-data"
    end    
    
    if extensions and extensions.size > 0
      str += "Sec-WebSocket-Extensions: #{extensions.join(',')}\r\n"
    end
    str += "\r\n"
  end
  
  def check_handshake_response(headers)
    return false if headers[0] != "HTTP/1.1 101 Switching Protocols"
    h = extract_headers(headers[1..headers.size])
    keys = ['Upgrade', 'Connection', 'Sec-WebSocket-Accept']
    keys.each do |key|
      return false if h.has_key?(key) == false
    end
    return false if h['Upgrade'].downcase != 'websocket' or h['Connection'].downcase != 'upgrade' or h['Sec-WebSocket-Accept'] != handshake_reponse(@handshake)

    if h.has_key?('Sec-WebSocket-Extensions') and h['Sec-WebSocket-Extensions'] == 'deflate-application-data'
      if @compression
        @zout = Zlib::Deflate.new(Zlib::BEST_SPEED, Zlib::MAX_WBITS, 8, 1)
        @zin = Zlib::Inflate.new
      end      
    else
      @compression = false
    end    
    
    @connected = true
    return true
  end
  
  def read_data(sock, buffer="")
    raise "not connected" if !@connected 
    fin, opcode, payload = read_frame(sock)
    case opcode
    when 0x0 # continuation frame
      return read_data(sock, buffer + payload)
    when 0x1 # text frame
      return buffer + payload if fin
    when 0x2 # bin frame
      return buffer + payload if fin
    when 0x8 # connection close
      @close_received = true
    when 0x9 # ping
      # send pong
      frames = create_frame(0xa, payload)
      sock.write(frame)      
    when 0xa # pong
      @pong_received = true
    end
  end
    
  def send_text_data(sock, data, frame_size)
    raise "not connected" if !@connected 
    frames = []
    if frame_size and frame_size < data.size
      # split data into several frames
      cnt = (data.size / 1.0 / frame_size).ceil
      cnt.times do |i|
        if i + 1 == cnt
          last_frame = true
        else
          last_frame = false
        end
        idx1 = frame_size*i
        idx2 = frame_size
#        puts "last - #{last_frame} #{idx1}-#{idx1+idx2}: #{data[idx1,idx2]}"
        frames << create_frame(0x1, data[idx1,idx2], last_frame)
      end
    else
      frames << create_frame(0x1, data)
    end
    frames.each do |frame|
      sock.write(frame)
    end
  end
  
  def close_connection(sock, code, message)
    @connected = false
    payload = ""
    if code and (code.kind_of?(Integer) == false or code > 65536)
      raise "Invalid close status code"
      payload << [code].pack('n')
      if message
        payload << message
      end
    end
    frame = create_frame(0x8, payload)
    sock.write(frame)
    if @close_received
      finalize_zlib
      return true
    else
      # read up ro 100 hundered frames and exit it there is close frame 
      100.times do |x|
        fin, opcode, payload = read_frame(sock)
        if opcode == 0x8
          finalize_zlib
          return true           
        end
      end
      finalize_zlib
      return false
    end
  end
  
  def ping(sock, text)
    frame = create_frame(0x9, text)
    sock.write(frame)    
    fin, opcode, payload = read_frame(sock)
    if opcode == 0xa and payload == text
      return true
    else
      return false
    end
  end
    
  
  private
  
  def extract_headers(headers)
    res = {}
    headers.each do |header|
      v = header.split(':')
      name = v[0].strip
      value = v[1].strip
      res[name] = value
    end
    return res
  end
  
  def mask_payload(payload)
    if !@masking_disabled
      masking_key = ''
      masking_key << rand(255)
      masking_key << rand(255)
      masking_key << rand(255)
      masking_key << rand(255)
    
      masked_payload = ""
      i = 0
      payload.each_byte do |byte|
        idx = i % 4
        masked_payload << (byte ^ masking_key[idx])
        i += 1
      end    
      return masking_key, masked_payload
    else
      return "", payload
    end
  end
  
  def read_frame(sock)
    # first byte
    b1 = sock.read(1)
    b1 = b1.unpack('C*')[0]
    fin = (b1 & 0b10000000) == 0b10000000
    opcode = (b1 & 0b00001111) 
    # second byte (masking and payload length)
    b2 = sock.read(1)
    b2 = b2.unpack('C*')[0]
    mask = (b2 & 0b10000000) # MASK bit 
    
    # 2DO throw exception if mask bit is set (sever should not send masked data)
    
    len = (b2 & 0b01111111)
    @logger.debug("fin - #{fin} opcode - #{opcode} mask - #{mask} len - #{len}") 
    len = case len
      when 126
        b = sock.read(2)
        len = b.unpack('n*')[0]
      when 127
        b = sock.read(8)
        len = b.unpack('N')[0]
      else
        len
      end
      
    # read payload
    @logger.debug("payload length - #{len}") 
    payload = sock.read(len)
    
    return fin, opcode, payload
  end
  
  def create_frame(opcode, d, last_frame = true)
    if last_frame == false and opcode >= 0x8 and opcode <= 0xf
      raise "Attempt to fragment control frame"
    end
    # apply per frame compression
    data = compress(d)    
    frame = ''
    byte1 = opcode
    byte1 = byte1 | 0b10000000 if last_frame
    frame << byte1
    length = data.size
    @logger.debug("payload length - #{length}") 
    if length <= 125
      if !@masking_disabled
        byte2 = (length | 0b10000000)  # set masking bit
      else
        byte2 = length
      end
      frame << byte2
    elsif length < 65536 # write 2 byte length
      frame << (126 | 0b10000000)
      frame << [length].pack('n')
    else # write 8 byte length
      frame << (127 | 0b10000000)
      frame << ([length >> 32, length & 0xFFFFFFFF].pack("NN"))
    end
  
    # mask data    
    mask_key, masked_payload = mask_payload(data)
    frame << mask_key if mask_key
    frame << masked_payload if masked_payload
    frame
  end
  
  def compress(data)
    if @compression and data.size > 0
      out = @zout.deflate(data, Zlib::SYNC_FLUSH)
      @logger.debug("compressed #{data.size} into #{out.size}") 
      return out[0,out.size-4]
    else
      return data
    end
  end
  
  def decomress(data)
    if @compression and data.size > 0
      # add trailer
      out = @zin.inflate(data << "\000\000\377\377")
      @logger.debug("decompressed #{data.size} into #{out.size}") 
    else
      return data
    end
  end
  
  def finalize_zlib
    if @compression
      @logger.debug("finalizying zlib") 
      @zin.close  # if @zin.closed? == false
      @zout.close # if @zout.closed? == false
    end
  end

  def make_handshake_key
    key = ""
    16.times {|x| key << rand(255)}
    Base64.encode64(key).strip
  end
  
  def handshake_reponse(handshake)
    str = handshake +"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    return Base64.encode64(Digest::SHA1.digest(str)).strip
  end
  
  
end