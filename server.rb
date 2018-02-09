require 'active_support/all'
require 'sucker_punch'
require 'sinatra'
require 'socket'                 # Get sockets from stdlib
#require 'bcrypt'

load 'command.rb'

configure {
	  set :server, :puma
}
set :environment, :production
set :show_exceptions, :after_handler
enable :sessions
set :sessions, true

class HomeHandler
  attr_reader :id, :port
  def initialize(id, port)
    @port = port
    @id = id
    @commands = []
    server = TCPServer.open(port)    # Socket to listen on port 2000
    @closed = false
    Thread.start() do |client|
      while (!@closed) do
        puts "Server.accept"
        @client = server.accept
        @client.puts(Request.identify)
        line = @client.gets
        response = Response.from_cmd(line)
        if response.valid_token?
          @client.puts Command.welcome
        else
          @client.puts Command.bye
          @client.close                  # Disconnect from the client
          @client = nil
        end
      end
      puts "stop listening"
    end
  end

  def close
    @closed = true
    @client&.close
  end

  def send_command(cmd)
    @commands << [Time.now, cmd]
    @client.puts cmd if @client
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

	get '/:id/bye' do
    client = CLIENTS[params[:id]]
	  client.send_command(Command.bye)
    client.close
    CLIENTS.delete(params[:id])
    "BYE"
	end

	get '/:id/heartbeat' do
    client = CLIENTS[params[:id]]
	  client.send_command(Command.heartbeat)
    "heartbeat"
	end

	get '/:id/on' do
    client = CLIENTS[params[:id]]
	  client.send_command(Command.turn_on)
    "heartbeat"
	end

	get '/:id/off' do
    client = CLIENTS[params[:id]]
	  client.send_command(Command.turn_off)
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


