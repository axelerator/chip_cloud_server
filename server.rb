require 'sucker_punch'
require 'sinatra'
require 'socket'                 # Get sockets from stdlib

class HomeHandler
  def initialize
    server = TCPServer.open(2000)    # Socket to listen on port 2000
    Thread.start() do |client|
      loop {
        @client = server.accept
        @client.puts("IDENTIFY")   # Send the time to the client
        line = @client.gets
        if line == "secret\n"
          @client.puts "WELCOME"
        else
          @client.puts "WRONG. BYE"
          @client.close                  # Disconnect from the client
          @client = nil
        end
      }
    end
  end

  def send_command(cmd)
    @client.puts cmd
  end
end

HHT = HomeHandler.new


get '/' do
  'Hello world!'
end

get '/foo' do
  HHT.send_command 'Toll'
  "foo#{HHT.class.name}"
end

