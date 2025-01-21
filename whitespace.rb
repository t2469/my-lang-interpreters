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
    rescue StandardError => e
      puts "Error: #{e.message}"
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
    @labels = {}
    @labels = Hash.new do |h, k|
      @tokens.each_with_index do |(imp, cmd, par), idx|
        h[par] = idx if cmd == :label_mark
      end
      h[k]
    end
    evaluate
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

  def evaluate
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
        # exec_flowで:endが来たらbreakする
        finished = exec_flow(cmnd, prmt)
        break if finished
      when :io
        exec_io(cmnd)
      end
    end
  rescue => e
    puts "実行エラー: #{e.message}"
  end

  def exec_stack(cmnd, prmt)
    case cmnd
    when :push
      @stack.push(prmt)
    when :duplicate
      @stack.push(@stack.last)
    when :n_duplicate
      n = convert_to_decimal(@stack.pop)
      @stack.push(@stack[n])
    when :swap
      @stack.push(@stack.slice!(-2))
    when :discard
      @stack.pop
    when :n_discard
      idx = convert_to_decimal(@stack.pop)
      @stack.delete_at(idx)
    else
      raise "構文エラー #{cmnd}"
    end
  end

  def exec_arithmetic(cmnd)
    raise "スタック要素不足" if @stack.size < 2
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
            raise "ゼロ除算" if b == 0
            a / b
          when :modulo
            raise "ゼロ除算" if b == 0
            a % b
          else
            raise "構文エラー: #{cmnd}"
          end

    if ans < 0
      ans = -ans
      result = "1#{ans.to_s(2)}"
    else
      result = "0#{ans.to_s(2)}"
    end
    @stack.push(result)
  end

  def exec_heap(cmnd)
    case cmnd
    when :h_push
      value = @stack.pop
      addr = convert_to_decimal(@stack.pop)
      @heap[addr] = value
    when :h_pop
      addr = convert_to_decimal(@stack.pop)
      @stack.push(@heap.fetch(addr, "0"))
    else
      raise "構文エラー #{cmnd}"
    end
  end

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
      @pc = @labels[prmt] if convert_to_decimal(@stack.pop).zero?
    when :jump_negative
      @pc = @labels[prmt] if convert_to_decimal(@stack.pop).negative?
    when :sub_end
      @pc = @subroutines.pop
    when :end
      return true
    else
      raise "構文エラー #{cmnd}"
    end
    false
  end

  def exec_io(cmnd)
    case cmnd
    when :output_char
      print convert_to_decimal(@stack.pop).chr
    when :output_num
      print convert_to_decimal(@stack.pop)
    when :input_char
      addr = convert_to_decimal(@stack.pop)
      c = $stdin.getc
      @heap[addr] = encode_number(c.ord)
    when :input_num
      addr = convert_to_decimal(@stack.pop)
      n = $stdin.gets.to_i
      @heap[addr] = encode_number(n)
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
    sign == '1' ? -value : value
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