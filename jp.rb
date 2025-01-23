#!/usr/bin/ruby
require 'strscan'

#================================================
# 生成規則（文法定義）
#================================================
# 文列 = 文 (文)*
# 文 = 代入文 | ‘もし’文 | '繰り返し’'文 | print文 | '{' 文列 '}'
# 代入文 = 変数 ':=' 式 ';'
# もし文 = 'もし' 式 'ならば' 文 'そうでないなら' 文
# 繰り返し文 = '繰り返し' 式 文
# 表示文 = '表示' 式 ';'
# 式 = 項 (( '+' | '-' ) 項)*
# 項 = 因子 (( '*' | '/' ) 因子)*
# 因子 := '-'? (リテラル | '(' 式 ')')

class Jp
  DEBUG = true

  #================================================
  # 字句解析用の変数定義
  #================================================
  @@keywords = {
    '+' => :add,
    '-' => :sub,
    '*' => :mul,
    '/' => :div,
    '%' => :mod,
    '(' => :lpar,
    ')' => :rpar,
    ':=' => :assign,
    ';' => :semi,
    'もし' => :if,
    'ならば' => :then,
    'そうでないなら' => :else,
    '繰り返し' => :for,
    '出力' => :print,
    '{' => :lbrace,
    '}' => :rbrace
  }.freeze

  #================================================
  # 字句解析(Lexer)
  #================================================
  # 入力文字列をトークンに分割
  def get_token
    # キーワードのマッチング(演算子や予約語)
    if (ret = @scanner.scan(/\A\s*(#{@@keywords.keys.map { |t| Regexp.escape(t) }.join('|')})/))
      return @@keywords[ret]
    end

    # 数値リテラルの抽出(整数と小数)
    if (ret = @scanner.scan(/\A\s*([0-9.]+)/))
      return ret.to_f
    end

    # 入力終了判定
    if (ret = @scanner.scan(/\A\s*\z/))
      return nil
    end

    return :bad_token
  end

  # トークンを1つ戻す(パーザの先読みに使用)
  def unget_token
    @scanner.unscan
  end

  #================================================
  # 構文解析(Parser)
  #================================================
  # 式の解析
  def expression
    result = term
    while true
      token = get_token
      unless token == :add or token == :sub
        unget_token
        break
      end
      result = [token, result, term]
    end
    p ['E', result] if Jp::DEBUG
    return result
  end

  # 項の解析
  def term
    result = factor
    while true
      token = get_token
      unless token == :mul or token == :div
        unget_token
        break
      end
      result = [token, result, factor]
    end
    p ['T', result] if Jp::DEBUG
    return result
  end

  # 因子の解析(数値/括弧/単項演算子)
  def factor
    token = get_token
    minusflg = 1
    if token == :sub
      minusflg = -1
      token = get_token
    end

    if token.is_a? Numeric
      p ['F', token * minusflg] if Jp::DEBUG
      return token * minusflg
    elsif token == :lpar
      result = expression
      unless get_token == :rpar
        raise Exception, "unexpected token"
      end
      p ['F', [:mul, minusflg, result]] if Jp::DEBUG
      return [:mul, minusflg, result]
    else
      raise Exception, "unexpected token"
    end
  end

  #================================================
  # 意味解析(Evaluator)
  #================================================
  # 抽象構文木(AST)を評価・実行
  def eval(exp)
    if exp.instance_of?(Array)
      case exp[0]
      when :add
        return eval(exp[1]) + eval(exp[2])
      when :sub
        return eval(exp[1]) - eval(exp[2])
      when :mul
        return eval(exp[1]) * eval(exp[2])
      when :div
        return eval(exp[1]) / eval(exp[2])
      else
        return exp
      end
    else
      return exp
    end
  end

  #================================================
  # 実行環境
  #================================================
  def initialize
    if ARGV.empty?
      loop do
        print 'exp > '
        code = STDIN.gets.chomp
        exit if ["quit", "q", "bye", "exit"].include?(code)

        @scanner = StringScanner.new(code)
        begin
          ex = expression
          puts eval(ex)
        rescue Exception
          puts 'Bad Expression'
        end
      end
    else
      # ファイル実行
      file_path = ARGV[0]
      unless File.exist?(file_path)
        puts "ファイルが存在しません: #{file_path}"
        exit
      end
      @code = File.read(file_path)
      @scanner = StringScanner.new(@code)
      begin
        ex = expression
        puts eval(ex)
      rescue Exception
        puts 'Bad Expression'
      end
    end
  end
end

Jp.new
