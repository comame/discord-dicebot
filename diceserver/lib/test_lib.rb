require 'test/unit'

require_relative './lib'

module LibTest
  class DiceRollTest < Test::Unit::TestCase
    test 'ダイスを振れる' do
      result = Lib::roll_text 'Emoklore', '2DM<=3'
      assert result != nil
    end

    test '無効なダイス' do
      result = Lib::roll_text 'Emoklore', 'invalid dice'
      assert result == nil
    end

    test 'サポートされているゲームシステム' do
      assert Lib::supported_game?('Emoklore')
      assert !Lib::supported_game?('aaaaaaaaaa')
    end
  end

  class JsonValueTest < Test::Unit::TestCase
    test '1行' do
      result = Lib::json_value 'foo'
      expect = '{"body":"foo"}'
      assert_equal result, expect
    end

    test '複数行' do
      # JSON では文字列は \\n にエンコードされる
      result = Lib::json_value "foo\nbar"
      expect = '{"body":"foo\nbar"}'
      assert_equal result, expect
    end
  end

  class HandlerTest < Test::Unit::TestCase
    test '1行' do
      r = MockRequest.new 'Cthulhu7th', '1d10'
      res = Lib::handle r

      reg = /^{"body":"\(1D10\) ＞ \d\d?"}$/

      assert reg.match? res
    end

    test '複数行' do
      r = MockRequest.new 'Cthulhu7th', 'x2 1d10'
      res = Lib::handle r

      reg = /^{"body":"#1\\n\(1D10\) ＞ \d\d?\\n\\n#2\\n\(1D10\) ＞ \d\d?"}$/

      assert reg.match? res
    end

    test 'game未指定' do
      r = MockRequest.new nil, '1d10'
      status, err = Lib::handle r

      assert_equal status, 400
      assert_equal err, '{"error":"game が指定されていない"}'
    end

    test 'dice未指定' do
      r = MockRequest.new 'Emoklore', nil
      status, err = Lib::handle r

      assert_equal status, 400
      assert_equal err, '{"error":"dice が指定されていない"}'
    end

    test '認識できないゲームシステム' do
      r = MockRequest.new 'Emokloreee', '1d10'
      status, err = Lib::handle r

      assert_equal status, 400
      assert_equal err, '{"error":"認識できないゲームシステム"}'
    end

    test '不正なダイスロール' do
      r = MockRequest.new 'Emoklore', 'あああ'
      status, err = Lib::handle r

      assert_equal status, 400
      assert_equal err, '{"error":"ダイスロールに失敗"}'
    end
  end

  class MockRequest
    def initialize(game, dice)
      @game = game
      @dice = dice
    end

    def params()
      return {
        'game' => @game,
        'dice' => @dice,
      }
    end
  end
end
