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

  COMMAND_PATTERNS = {
    :stack => / |\n[ \t\n]/,
    :arithmetic => / [ \t\n]|\t[ \t]/,
    :heap => /[ \t]/,
    :flow => / [ \t\n]|\t[ \t\n]|\n\n/,
    :io => / [ \t]|\t[ \t]/
  }.freeze

  PARAMS_PATTERNS = {
    :stack => /[ \t]+\n/,
    :flow => /[ \t]+\n/
  }.freeze

  def initialize
    @scanner = nil
  end

  def tokenize(code)
    tokens = []
    @scanner = StringScanner.new(code)
    return if @scanner == nil

    until @scanner.eos?
      # IMP切り出し
      imp = extract_imp(@scanner)
      if imp.nil?
        @scanner.getch
        next
      end

      # コマンド切り出し
      command = extract_command(@scanner, imp)
      if command.nil?
        @scanner.getch
        next
      end

      # パラメータ切り出し
      params = nil
      if has_params?(imp, command)
        params = extract_parameter(@scanner, imp)
        raise "パラメータが定義されていません。#{@scanner.pos}" unless params
      end

      tokens << [imp, command, params]
    end
    tokens
  end

  # -----------------------
  #  ヘルパーメソッド
  # -----------------------

  # impの切り出しメソッド
  def extract_imp(scanner)
    pattern = /\A( |\n|\t[ \n\t])/
    IMPS[scanner.scan(pattern)]
  end

  # commandの切り出しメソッド
  def extract_command(scanner, imp)
    pattern = COMMAND_PATTERNS[imp]
    command = scanner.scan(pattern)
    COMMANDS[imp][command]
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

  def extract_parameter(scanner, imp)
    pattern = PARAMS_PATTERNS[imp]
    scanner.scan(pattern)
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