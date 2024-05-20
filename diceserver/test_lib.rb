require 'test/unit'

require './lib'

module LibTest
  class DiceRollTest < Test::Unit::TestCase
    def test_ダイスを振れる
      result = Lib::roll_text? 'Emoklore', '2DM<=3'
      assert result != nil
    end

    def test_無効なゲームルール
      result = Lib::roll_text? 'invalid game', '1d10'
      assert result == nil
    end

    def test_無効なダイス
      result = Lib::roll_text? 'Emoklore', 'invalid dice'
      assert result == nil
    end
  end

  class JsonValueTest < Test::Unit::TestCase
    def test_1行
      result = Lib::json_value 'foo'
      expect = '{"body":"foo"}'
      assert result == expect
    end

    def test_複数行
      # JSON では文字列は \\n にエンコードされる
      result = Lib::json_value "foo\nbar"
      expect = '{"body":"foo\nbar"}'
      assert result == expect
    end
  end

  class HttpTest < Test::Unit::TestCase
    require 'json'
    require 'net/http'

    def setup
      @t = Thread::new do
        main
      end
      sleep 0.01
    end

    def teardown
      @t.kill
    end

    def test_ダイスを振れる
      res = Net::HTTP.get('localhost', '/?game=Emoklore&dice=1d10', 8081)
      res = JSON.parse(res)
      reg = /^\(1D10\) ＞ \d\d?$/

      assert reg.match?(res['body'])
    end

    def test_複数行のダイスを振れる
      res = Net::HTTP.get('localhost', '/?game=Cthulhu7th&dice=x2+1d100', 8081)
      res = JSON.parse(res)
      reg = /^#1\n\(1D100\) ＞ \d\d?\n\n#2\n\(1D100\) ＞ \d\d?$/

      assert reg.match?(res['body'])
    end
  end
end
