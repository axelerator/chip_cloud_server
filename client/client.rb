require 'socket'        # Sockets are in standard library
require 'net/http'
require 'json'

load 'command.rb'

DRY_MODE = false
begin
  require 'chip-gpio'
  PINS = ChipGPIO.get_pins
  PINS[:XIO7].export
  PINS[:XIO7].direction = :output
  PINS[:XIO7].value = 0
rescue NameError
  DRY_MODE = true
end

class Client
  attr_accessor :socket, :done
  def initialize
    @done = false
    #@hostname = 'localhost'
    @hostname = '192.168.178.56'
    @web_port = ':9292'
    #@hostname = 'axelerator.de'
    #@web_port = ''
  end

  def register
    uri =  URI("http://#{@hostname}#{@web_port}/register?id=chip")
    response = Net::HTTP.get(uri)
    @port = JSON.parse(response)['port'].to_i
    self
  end

  def listen
    @socket = TCPSocket.open(@hostname, @port)
    while !done && line = @socket.gets     # Read lines from the socket
      cmd = Command.from_cmd(line)
      cmd.client_action(self)
    end
    @socket.close                 # Close the socket when done
  end
end

Client.new.register.listen


