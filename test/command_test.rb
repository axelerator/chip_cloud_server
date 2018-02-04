require "minitest/autorun"

require 'command'

class TestMeme < Minitest::Test
  def test_that_serialization_works
    cmd = Command::AnswerToken.new
    assert_equal 'ANSWER_TOKEN', cmd.to_cmd.split(':').first
  end

  def test_that_deserialization_works
    cmd = Command.from_cmd('ANSWER_TOKEN:secret')
    assert_kind_of Command::AnswerToken, cmd
    assert_equal 'secret', cmd.token

    cmd = Command.from_cmd('ANSWER_TOKEN: secret')
    assert_kind_of Command::AnswerToken, cmd
    assert_equal 'secret', cmd.token
  end

  def test_anser_token_serialization
    cmd_str = 'ANSWER_TOKEN:secret'
    cmd = Command.from_cmd(cmd_str)
    assert_equal cmd_str, cmd.to_cmd
  end


end
