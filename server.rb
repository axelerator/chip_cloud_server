require 'active_support/all'
require 'sucker_punch'
require 'sinatra'
require 'socket'                 # Get sockets from stdlib
require 'timeout'
require 'eventmachine'
#require 'bcrypt'

load 'command.rb'

configure {
	  set :server, :puma
}
set :environment, :production
set :show_exceptions, :after_handler
enable :sessions
set :sessions, true

class HeartbeatJob
  include SuckerPunch::Job

  def perform(client_id, reschedule_in=nil)
    begin
      client = Pumatra::CLIENTS[client_id]
      Timeout.timeout(5) do
        heartbeat_result = client.send_command(Request.heartbeat)
        puts "HEARTBEAT -> #{client_id}: #{heartbeat_result}"
        if reschedule_in
          puts "Reschedule in #{reschedule_in}"
          self.class.perform_in(reschedule_in, client_id, reschedule_in)
        end
        heartbeat_result
      end
    rescue Timeout::Error
      client.close
      puts "Removed #{client_id} because unresponsive"
      Pumatra::CLIENTS.delete(client_id)
      "Timeout"
    end
  end
end

class EchoServer < EventMachine::Connection
  def initialize(handler)
    @handler = handler
    handler.socket = self
    @buffer = ''
  end

  def post_init
    puts "Challenge auth"
    puts "ID:#{@handler.id}"
    send_command(Request.identify)
  end

  def send_command(str)
    puts "SENDING '#{str}'"
    send_data str + "\n"
  end

  def receive_data data
    puts "Received data '#{data}'"
    @buffer += data
    if @buffer.include? "\n"
      cmd_strs = @buffer.split("\n")
      cmd_strs.each_with_index do |str, i|
        if i == cmd_strs.length < 1
          @buffer = str
        else
          unless data.strip.blank?
            puts "Parsing '#{data}'"
            response = Response.from_cmd(data.strip)
            handle_response(response)
          end
        end
      end
    end
  end

  def handle_response(response)
    if @handler.identified
      puts "ignore"
    else
      if response.valid_token?
       @handler.identified = true
       send_command(Request.welcome)
      else
        send_command Request.bye
        close_connection
      end
    end

  end

  def unbind
    puts "-- someone disconnected from the echo server!"
    @handler.socket = nil
  end
end

# Note that this will block current thread.


class HomeHandler
  attr_reader :id, :port
  attr_accessor :identified, :closed, :socket
  def initialize(id, port)
    @port = port
    @id = id
    puts "TCPServer open on port #{port}"
    @commands = []
    @identified = false
    @closed = false
    Thread.start() do |client|
      begin
        EventMachine.run {
          EventMachine.start_server "127.0.0.1", port, EchoServer, self
        }
=begin
          puts "Server.accept"
          @client = @server.accept
          puts "Sending: #{Request.identify}"
          @client.puts(Request.identify)
          line = @client.gets
          puts "DEBUG: #{line}"
          response = Response.from_cmd(line)
          if response.valid_token?
            send_command(Request.welcome)
          else
            @client.puts Request.bye
            @client.close                  # Disconnect from the client
            @client = nil
          end
        while (!@closed) do

        end
=end
        puts "stop listening"
      rescue StandardError => e
        puts e.message
        puts e.backtrace.first
      end
    end
  end

  def close
    @closed = true
    @client&.close
    @server&.close
  end

  def send_command(cmd)
    @commands << [Time.now, cmd] unless cmd.start_with? 'HEARTBEAT'
    #@client.puts cmd if @client
    #line = @client.gets
    #Response.from_cmd line
    @socket.send_command(cmd) if @socket
    #line
  end

  def api_state
    {
      id: @id,
      connected: !!@client,
      port: @port,
      commands: @commands
    }
  end

end

class APIError < StandardError
  def for_api
    {
      id: self.class.name.underscore.upcase,
      message: self.message
    }
  end
end

class UserMustNotBeEmpty < APIError; end
class WrongCredentials < APIError

  def message
    "Wrong password or username"
  end
end

class Pumatra < Sinatra::Base
  CREDS = {
    chip: 'batzen3000'
  }
  CLIENTS = {}

  USERS = {
    'at' => { password: 'batzen3000', sid: nil }
  }

  helpers do
    def current_user
      USERS.to_a.find{|name, details| details[:sid] == session[:user]}
    end
  end

	get '/' do
	  erb :index
	end

  get '/state' do
    {
      clients: CLIENTS.values.map(&:api_state),
      session: session
    }.to_json
  end

  post '/login' do
    raise UserMustNotBeEmpty if params[:user].blank?
    user = USERS[params[:user]]
    if user && params[:password] == user[:password]
      user[:sid] = SecureRandom.base64
      session[:user] = user[:sid]
      erb :dashboard
    else
      redirect '/?flash=wrong'
    end
  end

	get '/register' do
    begin
      id = params['id']
      raise APIError.new("not allowed") if id.nil? || id == '' || id.length > 512
      client = CLIENTS[id]
      unless client
        free_port = (CLIENTS.values.map(&:port).max || 1999) + 1
        puts "Registering new client '#{id}' on port #{free_port}"
        client = HomeHandler.new(id, free_port)
        CLIENTS[id] = client
      end
      {
        port: client.port
      }.to_json
    rescue APIError => e
      e.message
    end
	end


	post '/:id/:token/bye' do
    return halt(403, 'Go away') unless params[:token] == CREDS[params[:id].to_sym]
    client = CLIENTS[params[:id]]
	  client.send_command(Request.bye)
    client.close
    CLIENTS.delete(params[:id])
    "BYE"
	end

	post '/:id/:token/heartbeat' do
    return halt(403, 'Go away') unless params[:token] == CREDS[params[:id].to_sym]
    HeartbeatJob.new.perform(params[:id], 30)
	end

	post '/:id/:token/on' do
    return halt(403, 'Go away') unless params[:token] == CREDS[params[:id].to_sym]
    client = CLIENTS[params[:id]]
	  client.send_command(Request.turn_on)
    "heartbeat"
	end

	post '/:id/:token/off' do
    return halt(403, 'Go away') unless params[:token] == CREDS[params[:id].to_sym]
    client = CLIENTS[params[:id]]
	  client.send_command(Request.turn_off)
    "heartbeat"
	end

  error do
    if env['sinatra.error'].is_a? APIError
      env['sinatra.error'].for_api.to_json
    else
      "DAmn!"
    end
  end

  run! if app_file == $0
end


