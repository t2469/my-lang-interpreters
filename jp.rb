#!/usr/bin/ruby
require 'strscan'

class Jp
  DEBUG = true

  @@keywords = {
    '+' => :add,
    '-' => :sub,
    '*' => :mul,
    '/' => :div,
    '%' => :mod,
    '(' => :lpar,
    ')' => :rpar
  }

  # 式 := 項 (('+'|'-') 項)*
  # 項 := 因子 (('*'|'/') 因子)*
  # 因子 := '-'? (リテラル | '(' 式 ')')

  def get_token
    if ret = @scanner.scan(/\A\s*(#{@@keywords.keys.map { |t| Regexp.escape(t) }.join('|')})/)
      return @@keywords[ret]
    end

    if ret = @scanner.scan(/\A\s*([0-9.]+)/)
      return ret.to_f
    end

    if ret = @scanner.scan(/\A\s*\z/)
      return nil
    end

    return :bad_token
  end

  def unget_token
    @scanner.unscan
  end

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
    p ['E', result] if Calc::DEBUG
    return result
  end

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
    p ['T', result] if Calc::DEBUG
    return result
  end

  def factor
    token = get_token
    minusflg = 1
    if token == :sub
      minusflg = -1
      token = get_token
    end

    if token.is_a? Numeric
      p ['F', token * minusflg] if Calc::DEBUG
      return token * minusflg
    elsif token == :lpar
      result = expression
      unless get_token == :rpar
        raise Exception, "unexpected token"
      end
      p ['F', [:mul, minusflg, result]] if Calc::DEBUG
      return [:mul, minusflg, result]
    else
      raise Exception, "unexpected token"
    end
  end

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

  def initialize
    if ARGV.empty?
      # ファイルを指定しなければいけない場合
      # puts "ファイルを指定してください。"
      # exit

      # 今回は逐次実行
      loop do
        print 'exp > '
        code = STDIN.gets.chomp
        if ["quit", "q", "bye", "exit"].include?(code)
          exit
        end

        @scanner = StringScanner.new(code)
        begin
          ex = expression
          puts eval(ex)
        rescue Exception
          puts 'Bad Expression'
        end
      end
    else
      # ファイルが指定してあるのなら、そのプログラムを実行する
      file_path = ARGV[0]
      unless File.exist?(file_path)
        puts "ファイルが存在しません: #{file_path}"
        exit
      end
    end
  end
end

Calc.new
