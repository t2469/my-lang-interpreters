require "strscan"

class Whitespace
  def initialize
    ## 変数定義
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
    rescue SyntaxError => e
      puts "構文エラー: #{e.message}"
      exit
    end

    @tokens = []
    @token_list.each_slice(3) do |imp, cmd, par|
      @tokens << [imp, cmd, par]
    end

    ## 意味解析
    @output = ""
    @stack = []
    @heap = Hash.new(0)
    @pc = 0
    @subroutines = []
    @labels = Hash.new do |h, k|
      @tokens.each_with_index do |(imp, cmd, par), idx|
        h[par] = idx if cmd == :label_mark
      end
      h[k]
    end
    evaluate
  end

  #================================================
  # 字句解析
  #================================================
  def tokenize
    tokens = []
    scanner = StringScanner.new(@code)

    until scanner.eos?
      # IMP切り出し
      imp = get_imp(scanner)
      raise SyntaxError, "IMPが定義されていません。" if imp.nil?

      # コマンド切り出し
      command = get_command(scanner, imp)
      raise SyntaxError, "コマンドが定義されていません。" if command.nil?

      # パラメータ切り出し(必要なら)
      params = nil
      params = get_params(scanner) if parameter_check(imp, command)

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
      when "\t"
        ret << "1"
      end
    end
    ret.join
  end

  #================================================
  # 意味解析
  #================================================
  def evaluate
    begin
      loop do
        imp, cmnd, prmt = @tokens[@pc]
        @pc += 1
        case imp
        when :stack
          exec_stack(cmnd, prmt)
        when :arithmetic
          exec_arithmetic(cmnd)
        when :heap
          exec_heap(cmnd)
        when :flow
          finished = exec_flow(cmnd, prmt)
          break if finished
        when :io
          exec_io(cmnd)
        else
          raise SyntaxError, "未知のIMP: #{imp}"
        end
      end
    rescue SyntaxError => e
      puts "構文エラー: #{e.message}"
      exit 1
    rescue ZeroDivisionError => e
      puts "ゼロ除算エラー: #{e.message}"
      exit 1
    rescue ArgumentError => e
      puts "引数エラー: #{e.message}"
      exit 1
    rescue StandardError => e
      puts "実行時エラー: #{e.message}"
      exit 1
    end
  end

  #================================================
  # スタック処理
  #================================================
  def exec_stack(cmnd, prmt)
    case cmnd
    when :push
      @stack.push(prmt)
    when :duplicate
      raise ArgumentError, "スタック要素不足:duplicate" if @stack.empty?
      @stack.push(@stack.last)
    when :n_duplicate
      raise ArgumentError, "スタック要素不足:n_duplicate" if @stack.size < 1
      n = convert_to_decimal(@stack.pop)
      raise ArgumentError, "nがスタックの範囲外です" if n >= @stack.size || n < 0
      @stack.push(@stack[n])
    when :swap
      raise ArgumentError, "スタック要素不足:swap" if @stack.size < 2
      @stack.push(@stack.slice!(-2))
    when :discard
      raise ArgumentError, "スタックが空です" if @stack.empty?
      @stack.pop
    when :n_discard
      raise ArgumentError, "スタック要素不足:n_discard" if @stack.empty?
      idx = convert_to_decimal(@stack.pop)
      raise ArgumentError, "削除対象がスタック範囲外です" if idx >= @stack.size || idx < 0
      @stack.delete_at(idx)
    else
      raise SyntaxError, "不明なスタックコマンド: #{cmnd}"
    end
  end

  #================================================
  # 算術処理
  #================================================
  def exec_arithmetic(cmnd)
    raise ArgumentError, "スタック要素不足" if @stack.size < 2
    b = convert_to_decimal(@stack.pop)
    a = convert_to_decimal(@stack.pop)
    ans = case cmnd
          when :add
            a + b
          when :subtract
            a - b
          when :multiply
            a * b
          when :divide
            raise ZeroDivisionError, "0で除算はできません" if b == 0
            a / b
          when :modulo
            raise ZeroDivisionError, "0で割った剰余は定義できません" if b == 0
            a % b
          else
            raise SyntaxError, "不明な算術コマンド: #{cmnd}"
          end

    if ans < 0
      ans = -ans
      result = "1#{ans.to_s(2)}"
    else
      result = "0#{ans.to_s(2)}"
    end
    @stack.push(result)
  end

  #================================================
  # ヒープ処理
  #================================================
  def exec_heap(cmnd)
    case cmnd
    when :h_push
      raise ArgumentError, "スタック要素不足(h_push)" if @stack.size < 2
      value = @stack.pop
      addr = convert_to_decimal(@stack.pop)
      @heap[addr] = value
    when :h_pop
      raise ArgumentError, "スタックが空のため読み出せません(h_pop)" if @stack.empty?
      addr = convert_to_decimal(@stack.pop)
      @stack.push(@heap.fetch(addr, "0"))
    else
      raise SyntaxError, "不明なヒープコマンド: #{cmnd}"
    end
  end

  #================================================
  # フロー制御
  #================================================
  def exec_flow(cmnd, prmt)
    case cmnd
    when :label_mark
      @labels[prmt] = @pc
    when :sub_start
      @subroutines.push(@pc)
      @pc = @labels[prmt]
    when :jump
      @pc = @labels[prmt]
    when :jump_zero
      val = convert_to_decimal(@stack.pop)
      @pc = @labels[prmt] if val.zero?
    when :jump_negative
      val = convert_to_decimal(@stack.pop)
      @pc = @labels[prmt] if val < 0
    when :sub_end
      @pc = @subroutines.pop
    when :end
      return true
    end
    false
  end

  #================================================
  # IO
  #================================================
  def exec_io(cmnd)
    case cmnd
    when :output_char
      raise ArgumentError, "スタックが空のため出力できません" if @stack.empty?
      print convert_to_decimal(@stack.pop).chr
    when :output_num
      raise ArgumentError, "スタックが空のため出力できません" if @stack.empty?
      print convert_to_decimal(@stack.pop)
    when :input_char
      raise ArgumentError, "スタックが空のため入力先アドレスが取得できません" if @stack.empty?
      addr = convert_to_decimal(@stack.pop)
      c = $stdin.getc
      @heap[addr] = encode_number(c.ord)
    when :input_num
      raise ArgumentError, "スタックが空のため入力先アドレスが取得できません" if @stack.empty?
      addr = convert_to_decimal(@stack.pop)
      n = $stdin.gets.to_i
      @heap[addr] = encode_number(n)
      raise SyntaxError, "不明なIOコマンド: #{cmnd}"
    end
  end

  def encode_number(n)
    if n < 0
      "1#{(-n).to_s(2)}"
    else
      "0#{n.to_s(2)}"
    end
  end

  def convert_to_decimal(bin_str)
    sign = bin_str[0]
    value = bin_str[1..-1].to_i(2)
    sign == "1" ? -value : value
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
  rescue SyntaxError => e
    puts "構文エラー: #{e.message}"
    exit 1
  rescue StandardError => e
    puts "エラー: #{e.message}"
    exit 1
  end
end

main