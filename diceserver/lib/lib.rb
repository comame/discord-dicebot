# frozen_string_literal: true

require 'bcdice'
require 'bcdice/game_system'
require 'sinatra'

require 'socket'
require 'uri'
require 'json'

module Lib
  class << self
    def roll_text(game_system, dice)
      game = BCDice.game_system_class(game_system)
      raise 'BCDice.game_system_class の呼び出しに失敗した。game_system が有効か事前に確認すること' if game.nil?

      result = game.eval(dice)
      return nil if result.nil?

      result.text
    end

    @@game_system_names = BCDice.all_game_systems.map do |c|
      c::ID
    end

    def supported_game?(game_system)
      @@game_system_names.include? game_system
    end

    def handle(request)
      game = request.params['game']
      dice = request.params['dice']

      return 400, json_error('game が指定されていない') if game.nil?
      return 400, json_error('dice が指定されていない') if dice.nil?

      return 400, json_error('認識できないゲームシステム') unless supported_game? game

      result = roll_text game, dice
      return 400, json_error('ダイスロールに失敗') if result.nil?

      json_value result
    end

    def json_error(message)
      JSON.generate({ error: message })
    end

    def json_value(message)
      JSON.generate({ body: message })
    end
  end
end

def startup_app
  set :port, 8081
  disable :run
  set :environment, 'production'

  get '/' do
    Lib.handle request
  end

  Sinatra::Application.run!
end
