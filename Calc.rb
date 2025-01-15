require 'strscan'

class Calc
  keywords = {
    '+' => :add,
    '-' => :sub,
    '*' => :mul,
    '/' => :div,
    '(' => :left_parn,
    ')' => :right_parn
  }

  def initialize(input)
    @input = StringScanner.new(input)
  end

  # 意味解析
  def eval(exp)
    if exp.instrance_of?(Array)
      case exp[0]
      when :add
        eval(exp[1]) + eval(exp[2])
      when :sub
        eval(exp[1]) - eval(exp[2])
      when :mul
        eval(exp[1]) * eval(exp[2])
      when :div
        eval(exp[1]) / eval(exp[2])
      else
        exp
      end
    end
  end

  def expression()
    result = term
    token = get_token
    while token == :add or token == :sub
      result = [token, result, term]
      token = get_token
    end
    unget_token(token)
    result
  end

  def term
    result = factor
    token = get_token
    while token == :mul or token == :div
      result = [token, result, factor]
      token = get_token
    end
    unget_token(token)
    result
  end

  def factor
    token = get_token
    if token === Integer # トークンがリテラルか
      result = token # リテラル
    elsif token == :left_parn || token == :right_parn # トークンが開きカッコか
      # result = ????
      get_token # 閉じカッコを取り除く（使用しない: カッコは構文木に現れない。）
    else
      raise Exception, “構文エラー”
    end
    return result
  end

  def parse
    expression
  end

  def get_token
    input = @input.scan(/.+/)
    if keywords.has_key?(input)
      input
    else
      begin
        Integer(input)
      rescue => e
        raise Exception, “構文エラー”
      end
    end
  end

  def unget_token(token)
    @input.unscan
  end
end


if  ARGV.empty?
  puts "構文エラーです。"
  return
end

Calc.new(ARGV[0])
