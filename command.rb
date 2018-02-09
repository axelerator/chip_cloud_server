require 'active_support/all'

class Command

  def self.inherited(subclass)
    self.define_singleton_method subclass.name.demodulize.underscore do |args = nil|
      c = subclass.new
      c.init(args) if args
      c.to_cmd
    end
  end

  def client_action(client)
    puts "NOOP#{self.class.name} "
  end

  class AnswerToken < Command
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

  class Identify < Command
    def client_action(client)
      client.socket.puts Command.answer_token('secret')
    end

  end

  class Heartbeat < Command
    def client_action(client)
      puts "Ansering heartbeat"
    end
  end

  class Welcome < Command
  end

  class TurnOn < Command
    def client_action(client)
      if DRY_MODE
        puts "turning pin on"
      else
        PINS[:XIO7].value = 1
      end
    end
  end

  class TurnOff < Command
    def client_action(client)
      if DRY_MODE
        puts "turning pin off"
      else
        PINS[:XIO7].value = 0
      end
    end
  end

  class Bye < Command
    def client_action(client)
      client.done = true
    end
  end

  def init(args_as_string)
    # override to parse
  end

  def self.from_cmd(str)
    begin
      class_name, *rest = str.split(':')
      cmd = Command.const_get(class_name.downcase.camelize).new
      cmd.init(rest.join(':').strip)
      cmd
    rescue StandardError => e
      puts "Unable to deserialize command #{str}"
      raise e
    end
  end

  def cmd_params
    nil
  end

  def to_cmd
    "#{self.class.name.demodulize.underscore.upcase}:#{cmd_params}"
  end


end

