require "bcdice"
require "bcdice/game_system"

require "socket"
require "uri"

# BCDice でダイスロールを行い、結果の文字列を返す。失敗したら nil を返す
def roll_text?(game_system, dice)
  game = BCDice.game_system_class(game_system)
  if game == nil then
    return nil
  end

  result = game.eval(dice)
  if result == nil then
    return nil
  end

  return result.text()
end

def json_error(message)
  return "{ \"error\": \"#{message}\" }"
end

def json_value(message)
  return "{ \"body\": \"#{message}\" }"
end

# `/` から始まる HTTP パス文字列を受け取り、`{ :game => "Emoklore", :dice => "2DM<=6" }` の Hash を返す
def parse_path?(path_string)
  q = path_string.slice!(2..(path_string.length()-1))
  if q == nil then
    return nil
  end

  m = {
    :game => '',
    :dice => '',
  }

  kvs = q.split("&")
  for i in 0..(kvs.size() - 1) do
    kv = kvs[i]
    sp = kv.split("=")
    if sp.length() != 2 then
      return nil
    end
    k = sp[0]
    v = URI.decode_www_form_component(sp[1])

    case k
    when "game" then
      m[:game] = v
    when "dice" then
      m[:dice] = v
    else
      return nil
    end
  end

  return m
end

# JSON 形式の HTTP レスポンスを返し、クローズする。
# `respond_http(cl, 200, "[]")`
def respond_http(client, status, body_json)
  status_str = ""
  case status
  when 200 then
    status_str = "OK"
  when 400 then
    status_str = "Bad Request"
  else
    status = 500
    status_str = "Internal Server Error"
  end

  client.puts("HTTP/1.1 " + status.to_s() + " " + status_str + "\r")
  client.puts("Content-Type: application/json\r")
  client.puts("\r")
  client.puts(body_json+"\r")

  client.close()
end

def handle(client)
  path = ""

  # リクエストをパース
  i = 0
  loop do
    l = client.gets()
    if l == nil || l.chomp().empty?() then
      break
    end

    # 開始行
    # https://developer.mozilla.org/ja/docs/Web/HTTP/Messages#%E9%96%8B%E5%A7%8B%E8%A1%8C
    if i == 0 then
      sp = l.split(" ")[1]
      if sp == nil then
        respond_http(client, 200, json_error("invalid http request format"))
        return
      end
      path = sp
    end

    i += 1
  end

  m = parse_path?(path)
  if m == nil then
    respond_http(client, 400, json_error("invalid request query"))
    return
  end

  result = roll_text?(m[:game], m[:dice])
  if result == nil then
    respond_http(client, 400, json_error("不正な入力"))
    return
  end

  respond_http(client, 200, json_value(result))
end

def main
  srv = TCPServer.new(8081)
  p "Start dicebot http://127.0.0.1:8081"

  loop do
    c = srv.accept()
    Thread.new(c) {|c|
      handle(c)
    }
  end
end

main()
