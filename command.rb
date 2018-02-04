require 'active_support/all'

class Command

  def self.inherited(subclass)
    self.define_singleton_method subclass.name.demodulize.underscore do |args = nil|
      c = subclass.new
      c.init(args) if args
      c.to_cmd
    end
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

  class Identify < Command; end
  class Heartbeat < Command; end
  class Welcome < Command; end
  class Bye < Command; end

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

