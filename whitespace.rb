require "strscan"

class Whitespace
  def initialize
    ## 定義
    @imps = {
      " " => :stack,
      "\t " => :arithmetic,
      "\t\t" => :heap,
      "\n" => :flow,
      "\t\n" => :io
    }.freeze

    @commands = {
      stack: {
        " " => :push, # [Space] Number
        "\n " => :duplicate, # [LF][Space]
        "\t " => :n_duplicate, # [Tab][Space] Number
        "\n\t" => :swap, # [LF][Tab]
        "\n\n" => :discard, # [LF][LF]
        "\t\n" => :n_discard # [Tab][LF] Number
      },
      arithmetic: {
        "  " => :add, # [Space][Space]
        " \t" => :subtract, # [Space][Tab]
        " \n" => :multiply, # [Space][LF]
        "\t " => :divide, # [Tab][Space]
        "\t\t" => :modulo # [Tab][Tab]
      },
      heap: {
        " " => :h_push, # [Space]
        "\t" => :h_pop # [Tab]
      },
      flow: {
        "  " => :label_mark, # [Space][Space] Label
        " \t" => :sub_start, # [Space][Tab] Label
        " \n" => :jump, # [Space][LF] Label
        "\t " => :jump_zero, # [Tab][Space] Label
        "\t\t" => :jump_negative, # [Tab][Tab] Label
        "\t\n" => :sub_end, # [Tab][LF]
        "\n\n" => :end # [LF][LF]
      },
      io: {
        "  " => :output_char, # [Space][Space]
        " \t" => :output_num, # [Space][Tab]
        "\t " => :input_char, # [Tab][Space]
        "\t\t" => :input_num # [Tab][Tab]
      }
    }.freeze

    @command_patterns = {
      stack: /\A( |\n[ \n\t]|\t[ \n])/,
      arithmetic: /\A( [ \t\n]|\t[ \t])/,
      heap: /\A([ \t])/,
      flow: /\A( [ \t\n]|\t[ \t\n]|\n\n)/,
      io: /\A( [ \t]|\t[ \t])/
    }.freeze

    ## ファイル読み込み
    @code = ARGF.readlines.join
    @code.gsub!(/[^ \t\n]/, "") # 空白文字以外は削除

    ## 字句解析
    begin
      @token_list = tokenize
    rescue StandardError => e
      puts "Error: #{e.message}"
    end
    puts @token_list.inspect

    @tokens = []
    @token_list.each_slice(3) do |imp, cmd, par|
      @tokens << [imp, cmd, par]
    end

    ## 意味解析

  end

  def tokenize
    tokens = []
    scanner = StringScanner.new(@code)

    until scanner.eos?
      # IMP切り出し
      imp = get_imp(scanner)
      raise "impが定義されていません。" if imp.nil?

      # コマンド切り出し
      command = get_command(scanner, imp)
      raise "commandが定義されていません。" if command.nil?

      # パラメータ切り出し(必要なら)
      params = nil
      if parameter_check(imp, command)
        params = get_params(scanner)
      end

      tokens << imp << command << params
    end
    tokens
  end

  def get_imp(scanner)
    if (imp_sc = scanner.scan(/\A( |\n|\t[ \n\t])/))
      return @imps[imp_sc]
    end
    nil
  end

  def get_command(scanner, imp)
    pattern = @command_patterns[imp]
    if (command_sc = scanner.scan(pattern))
      return @commands[imp][command_sc]
    end
    nil
  end

  def get_params(scanner)
    if (params_sc = scanner.scan(/\A([ \t]+\n)/))
      params_sc.chop!
      return str_to_i(params_sc)
    end
    nil
  end

  # 与えられたimp,commandのとき、paramsが必要とされているかを真偽値で返すメソッド
  def parameter_check(imp, command)
    case imp
    when :stack
      [:push, :n_duplicate, :n_discard].include?(command)
    when :flow
      [:label_mark, :sub_start, :jump, :jump_zero, :jump_negative].include?(command)
    else
      false
    end
  end

  def str_to_i(space)
    ret = []
    space.chars.each do |sp|
      case sp
      when " "
        ret << "0"
      when /\t/
        ret << "1"
      end
    end
    ret.join
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

  begin
    Whitespace.new
  rescue => error
    puts "エラー: #{error}"
  end
end

main