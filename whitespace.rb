def tokenize(code)
  tokens = []
  while code.length > 0
    # IMP切り出し
    # コマンド切り出し
    # パラメータ切り出し（必要なら）
    tokens << imp << command << params
  end
  return tokens
end

def main
  if ARGV.length == 0
    puts "ファイルを指定してください。"
    return
  end
  code = ARGV[0]
  tokenize(code)
end

main