class Whitespace
  def initialize
    @scanner = nil
  end

  def tokenize(code)
    tokens = []
    while code.length > 0
      # IMP切り出し

      # コマンド切り出し

      # パラメータ切り出し

      tokens << imp << command << params
    end
    tokens
  end

end

def main
  if ARGV.empty?
    puts "ファイルを指定してください。"
    exit
  end

  file_path = ARGV[0]
  unless File.exist?(file_path)
    puts "ファイルが存在しません: #{file_path}"
    exit
  end

  code = File.read(file_path)
  ws = Whitespace.new
  begin
    tokens = ws.tokenize(code)
    puts tokens.inspect
  rescue => error
    puts "エラー: #{error}"
  end
end

main