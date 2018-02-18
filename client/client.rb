require 'socket'        # Sockets are in standard library
require 'net/http'
require 'json'
require 'yaml'

load 'command.rb'
CONFIG = YAML.load_file('config.yml')
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
    @hostname = CONFIG['server']['host']
    @web_port = CONFIG['server']['port']
    @web_port = @web_port.present? ? ":#{@web_port}" : ''
    @protocol = CONFIG['server']['protocol']
  end

  def register
    uri =  URI("#{@protocol}://#{@hostname}#{@web_port}/register?id=chip")
    response = Net::HTTP.get(uri)
    @port = JSON.parse(response)['port'].to_i
    self
  end

  def listen
    @socket = TCPSocket.open(@hostname, @port)
    while !done && line = @socket.gets     # Read lines from the socket
      puts "received #{line}"
      cmd = Request.from_cmd(line)
      cmd.client_action(self)
      puts "Sending #{cmd.response}"
      @socket.puts cmd.response
    end
    @socket.close                 # Close the socket when done
  end
end

Client.new.register.listen


