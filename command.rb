require 'active_support/all'

class Command
  def init(args_as_string)
    # override to parse
  end

  def cmd_params
    nil
  end

  def to_cmd
    "#{self.class.name.demodulize.underscore.upcase}:#{cmd_params}"
  end
end

class Request < Command

  def self.inherited(subclass)
    self.define_singleton_method subclass.name.demodulize.underscore do |args = nil|
      c = subclass.new
      c.init(args) if args
      c.to_cmd
    end
  end

  def self.from_cmd(str)
    begin
      class_name, *rest = str.split(':')
      cmd = Request.const_get(class_name.downcase.camelize).new
      cmd.init(rest.join(':').strip)
      cmd
    rescue StandardError => e
      puts "Unable to deserialize command #{str}"
      raise e
    end
  end

  def client_action(client)
    puts "NOOP"
  end

  def response
    Response.received
  end

  class Identify < Request
    def response
      Response.answer_token('secret')
    end
  end

  class Welcome < Request
  end

  class Bye < Request
    def client_action(client)
      client.done = true
    end
  end

  class TurnOn < Request
    def client_action(client)
      if DRY_MODE
        puts "turning pin on"
      else
        PINS[:XIO7].value = 1
      end
    end
  end

  class TurnOff < Request
    def client_action(client)
      if DRY_MODE
        puts "turning pin off"
      else
        PINS[:XIO7].value = 0
      end
    end
  end

  class Heartbeat < Request
    def response
      Response.heartbeat
    end
  end

end

class Response < Command
  def self.inherited(subclass)
    self.define_singleton_method subclass.name.demodulize.underscore do |args = nil|
      c = subclass.new
      c.init(args) if args
      c.to_cmd
    end
  end

  def self.from_cmd(str)
    begin
      class_name, *rest = str.split(':')
      cmd = Response.const_get(class_name.downcase.camelize).new
      cmd.init(rest.join(':').strip)
      cmd
    rescue StandardError => e
      puts "Unable to deserialize command #{str}"
      raise e
    end
  end

  class AnswerToken < Response
    attr_reader :token
    def init(args)
      @token = args
    end

    def valid_token?
      @token == 'secret'
    end

    def cmd_params
      @token
    end
  end

  class Heartbeat < Response
  end

  class Received < Response
  end

end

