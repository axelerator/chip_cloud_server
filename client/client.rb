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

class Command
  def client_action(client)
    puts "NOOP#{self.class.name} "
  end

  class Identify
    def client_action(client)
      client.socket.puts Command.answer_token('secret')
    end
  end

  class Bye
    def client_action(client)
      client.done = true
    end
  end

  class TurnOff
    def client_action(client)
      if DRY_MODE
        puts "turning pin off"
      else
        PINS[:XIO7].value = 0
      end
    end
  end


  class TurnOn
    def client_action(client)
      if DRY_MODE
        puts "turning pin on"
      else
        PINS[:XIO7].value = 1
      end
    end
  end

end

class Client
  attr_accessor :socket, :done
  def initialize
    @done = false
    #@hostname = 'localhost'
    #@web_port = ':9292'
    @hostname = 'axelerator.de'
    @web_port = ''
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


