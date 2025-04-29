# frozen_string_literal: true

require 'rspec'
require_relative 'lib'

RSpec.describe Lib do
  describe '.roll_text' do
    context 'when rolling valid dice' do
      it 'returns a non-nil result' do
        result = Lib.roll_text 'Emoklore', '2DM<=3'
        expect(result).not_to be_nil
      end
    end

    context 'when rolling invalid dice' do
      it 'returns nil' do
        result = Lib.roll_text 'Emoklore', 'invalid dice'
        expect(result).to be_nil
      end
    end
  end

  describe '.supported_game?' do
    context 'when the game system is supported' do
      it 'returns true' do
        expect(Lib.supported_game?('Emoklore')).to be_truthy
      end
    end

    context 'when the game system is not supported' do
      it 'returns false' do
        expect(Lib.supported_game?('aaaaaaaaaa')).to be_falsey
      end
    end
  end

  describe '.json_value' do
    context 'when given a single-line string' do
      it 'returns a JSON string with the body key' do
        result = Lib.json_value 'foo'
        expect = '{"body":"foo"}'
        expect(result).to eq(expect)
      end
    end

    context 'when given a multi-line string' do
      it 'returns a JSON string with the body key and \\n for newlines' do
        # JSON では文字列は \\n にエンコードされる
        result = Lib.json_value "foo\nbar"
        expect = '{"body":"foo\nbar"}'
        expect(result).to eq(expect)
      end
    end
  end

  describe '.handle' do
    context 'when given valid game and dice' do
      it 'returns a JSON string with the dice roll result (single line)' do
        r = MockRequest.new 'Cthulhu7th', '1d10'
        res = Lib.handle r
        reg = /^{"body":"\(1D10\) ＞ \d\d?"}$/
        expect(res).to match(reg)
      end

      it 'returns a JSON string with the dice roll result (multi line)' do
        r = MockRequest.new 'Cthulhu7th', 'x2 1d10'
        res = Lib.handle r
        reg = /^{"body":"#1\\n\(1D10\) ＞ \d\d?\\n\\n#2\\n\(1D10\) ＞ \d\d?"}$/
        expect(res).to match(reg)
      end
    end

    context 'when game is not specified' do
      it 'returns a 400 status and an error JSON' do
        r = MockRequest.new nil, '1d10'
        status, err = Lib.handle r
        expect(status).to eq(400)
        expect(err).to eq('{"error":"game が指定されていない"}')
      end
    end

    context 'when dice is not specified' do
      it 'returns a 400 status and an error JSON' do
        r = MockRequest.new 'Emoklore', nil
        status, err = Lib.handle r
        expect(status).to eq(400)
        expect(err).to eq('{"error":"dice が指定されていない"}')
      end
    end

    context 'when the game system is not recognized' do
      it 'returns a 400 status and an error JSON' do
        r = MockRequest.new 'Emokloreee', '1d10'
        status, err = Lib.handle r
        expect(status).to eq(400)
        expect(err).to eq('{"error":"認識できないゲームシステム"}')
      end
    end

    context 'when the dice roll is invalid' do
      it 'returns a 400 status and an error JSON' do
        r = MockRequest.new 'Emoklore', 'あああ'
        status, err = Lib.handle r
        expect(status).to eq(400)
        expect(err).to eq('{"error":"ダイスロールに失敗"}')
      end
    end
  end
end

class MockRequest
  attr_reader :params

  def initialize(game, dice)
    @params = { 'game' => game, 'dice' => dice }
  end
end
