require "minitest/autorun"

require 'command'

class TestMeme < Minitest::Test
  def test_that_serialization_works
    cmd = Response::AnswerToken.new
    assert_equal 'ANSWER_TOKEN', cmd.to_cmd.split(':').first
  end

  def test_that_deserialization_works_for_identify
    cmd = Request.from_cmd('IDENTIFY:')
    assert_kind_of Request::Identify, cmd
  end

  def test_that_deserialization_works
    cmd = Response.from_cmd('ANSWER_TOKEN:secret')
    assert_kind_of Response::AnswerToken, cmd
    assert_equal 'secret', cmd.token

    cmd = Response.from_cmd('ANSWER_TOKEN: secret')
    assert_kind_of Response::AnswerToken, cmd
    assert_equal 'secret', cmd.token
  end

  def test_anser_token_serialization
    cmd_str = 'ANSWER_TOKEN:secret'
    cmd = Response.from_cmd(cmd_str)
    assert_equal cmd_str, cmd.to_cmd
  end


end
