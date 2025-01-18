require 'strscan'

class Whitespace
  IMPS = {
    " " => :stack,
    "\t " => :arithmetic,
    "\t\t" => :heap,
    "\n" => :flow,
    "\t\n" => :io
  }.freeze

  def initialize
    @scanner = nil
  end

  def tokenize(code)
    tokens = []
    while code.length > 0
      # IMP切り出し
      imp = extract_imp(@scanner)
      raise "IMPが定義されていません。 #{scanner.pos}" unless imp

      # コマンド切り出し

      # パラメータ切り出し

      tokens << imp << command << params
    end
    tokens
  end

  def extract_imp(scanner)
    IMPS.each do |key, symbol|
      if scanner.scan(key)
        return symbol
      end
    end
    nil
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