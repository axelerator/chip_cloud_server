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
    Thread.start() do |client|
      loop {
        @client = server.accept

        @client.puts(Command.identify)
        line = @client.gets
        response = Command.from_cmd(line)
        if response.valid_token?
          @client.puts Command.welcome
        else
          @client.puts Command.bye
          @client.close                  # Disconnect from the client
          @client = nil
        end
      }
    end
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
      free_port = (CLIENTS.values.map(&:port).max || 1999) + 1
      id = params['id']
      raise APIError.new("not allowed") if id.nil? || id == '' || id.length > 512
      raise APIError.new("already in use") if CLIENTS[id]
      new_handler = HomeHandler.new(id, free_port)
      CLIENTS[id] = new_handler
      {
        port: new_handler.port
      }.to_json
    rescue APIError => e
      e.message
    end
	end

	get '/:id/bye' do
    client = CLIENTS[params[:id]]
	  client.send_command(Command.bye)
    "BYE"
	end

	get '/:id/heartbeat' do
    client = CLIENTS[params[:id]]
	  client.send_command(Command.heartbeat)
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


