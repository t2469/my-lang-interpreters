require 'strscan'

class Whitespace
  IMPS = {
    " " => :stack,
    "\t " => :arithmetic,
    "\t\t" => :heap,
    "\n" => :flow,
    "\t\n" => :io
  }.freeze

  COMMANDS = {
    stack: {
      " " => :push, # [Space] Number
      "\n " => :duplicate, # [LF][Space]
      "\t " => :copy, # [Tab][Space] Number
      "\n\t" => :swap, # [LF][Tab]
      "\n\n" => :discard, # [LF][LF]
      "\t\n" => :slide # [Tab][LF] Number
    },
    arithmetic: {
      "  " => :add, # [Space][Space]
      " \t" => :subtract, # [Space][Tab]
      " \n" => :multiply, # [Space][LF]
      "\t " => :divide, # [Tab][Space]
      "\t\t" => :modulo # [Tab][Tab]
    },
    heap: {
      " " => :store, # [Space]
      "\t" => :retrieve # [Tab]
    },
    flow: {
      "  " => :mark_label, # [Space][Space] Label
      " \t" => :call_subroutine, # [Space][Tab] Label
      " \n" => :jump_unconditional, # [Space][LF] Label
      "\t " => :jump_if_zero, # [Tab][Space] Label
      "\t\t" => :jump_if_negative, # [Tab][Tab] Label
      "\t\n" => :end_subroutine, # [Tab][LF]
      "\n\n" => :end_program # [LF][LF]
    },
    io: {
      "  " => :output_char, # [Space][Space]
      " \t" => :output_number, # [Space][Tab]
      "\t " => :input_char, # [Tab][Space]
      "\t\t" => :input_number # [Tab][Tab]
    }
  }.freeze

  def initialize
    @scanner = nil
  end

  def tokenize(code)
    tokens = []
    @scanner = StringScanner.new(code)

    until @scanner.eos?
      # IMP切り出し
      imp = extract_imp(@scanner)
      raise "IMPが定義されていません。#{@scanner.pos}" unless imp

      # コマンド切り出し
      command = extract_command(@scanner, imp)
      raise "コマンドが定義されていません。#{@scanner.pos}" unless command

      # パラメータ切り出し
      if has_params?(imp, command)
        params = extract_parameter(@scanner, imp, command)
        raise "パラメータが定義されていません。#{@scanner.pos}" unless params
      end

      tokens << imp << command << params
    end
    tokens
  end

  # -----------------------
  #  ヘルパーメソッド
  # -----------------------
  def extract_imp(scanner)
    IMPS.each do |key, symbol|
      pattern = Regexp.new(Regexp.escape(key))
      if scanner.scan(pattern)
        return symbol
      end
    end

    nil
  end

  def extract_command(scanner, imp)
    cmd_map = COMMANDS[imp]
    return nil if cmd_map.nil?

    cmd_map.each do |key, symbol|
      pattern = Regexp.new(Regexp.escape(key))
      if scanner.scan(pattern)
        return symbol
      end
    end

    nil
  end

  # 与えられたIMP,commandのとき、paramsが必要とされているかを真偽値で返すメソッド
  def has_params?(imp, command)
    case imp
    when :stack
      [:push, :copy, :slide].include?(command)
    when :flow
      [:mark_label, :call_subroutine, :jump_unconditional, :jump_if_zero, :jump_if_negative].include?(command)
    else
      false
    end
  end

  def extract_parameter(scanner, imp, command)
    param_bits = ""
    while !scanner.eos? && [" ", "\t"].include?(scanner.peek(1))
      param_bits << scanner.getch
    end
    if scanner.peek(1) == "\n"
      scanner.getch
    end
    if imp == :stack && [:push, :copy, :slide].include?(command)
      bits_to_number(param_bits)
    elsif imp == :flow && [:mark_label, :call_subroutine, :jump_unconditional, :jump_if_zero, :jump_if_negative].include?(command)
      return param_bits
    else
      nil
    end
  end

  def bits_to_number(bits)
    return nil if bits.empty?

    sign = bits[0]
    number_part = bits[1..-1] || ""

    bin_string = number_part.gsub(" ", "0").gsub("\t", "1")
    return nil if bin_string.empty?

    value = bin_string.to_i(2)
    sign == "\t" ? -value : value
  rescue
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