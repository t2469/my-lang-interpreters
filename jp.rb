#!/usr/bin/ruby
require 'strscan'

#================================================
# 生成規則
#================================================
# 文列 = 文 (文)*
# 文 = 代入文 | ‘もし’文 | '繰り返し’'文 | print文 | '{' 文列 '}'
# 代入文 = 変数 ':=' 式 ';'
# もし文 = 'もし' 式 'ならば' 文 'そうでないなら' 文
# 繰り返し文 = '繰り返し' 式 文
# 出力文 = '出力' 式 ';'
# 式 = 項 (( '+' | '-' ) 項)*
# 項 = 因子 (( '*' | '/' ) 因子)*
# 因子 := '-'? (リテラル | '(' 式 ')')

class Jp
  DEBUG = true

  def initialize
    if ARGV.empty?
      puts "ファイルを指定してください。"
      exit
    end

    file_path = ARGV[0]
    unless File.exist?(file_path)
      puts "ファイルが存在しません: #{file_path}"
      exit
    end

    # 字句解析用のキーワード定義
    @keywords = {
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
      '}' => :rbrace,
      '==' => :eq,
      '!=' => :neq,
      '>=' => :gte,
      '<=' => :lte,
      '>' => :gt,
      '<' => :lt
    }.freeze

    # 変数を管理するハッシュ
    @space = {}

    code = File.read(file_path)
    @scanner = StringScanner.new(code)
    begin
      statements = parse_statements
      statements.each { |stmt| eval(stmt) }
    rescue => e
      puts "エラー: #{e.message}"
    end
  end

  #================================================
  # 字句解析(Lexer)
  #================================================
  def get_token
    # 空白をスキップ
    @scanner.skip(/\s+/)
    return nil if @scanner.eos?

    # キーワードのマッチング(演算子や予約語)
    @keywords.keys.each do |key|
      if @scanner.scan(Regexp.new(Regexp.escape(key)))
        return @keywords[key]
      end
    end

    # 変数名
    if (var = @scanner.scan(/\A[a-zA-Z_]\w*/))
      return [:var, var]
    end

    # 数値(整数や小数)
    if (num = @scanner.scan(/\A\d+(\.\d+)?/))
      return num.include?('.') ? num.to_f : num.to_i
    end

    bad = @scanner.getch
    raise "不正なトークンです: #{bad}"
  end

  def unget_token
    @scanner.unscan
  end

  #================================================
  # 構文解析(Parser)
  #================================================

  #-----------------------------------------------
  # 文列 = 文 (文)*
  #-----------------------------------------------
  def parse_statements
    stmts = []
    while (stmt = parse_statement)
      stmts << stmt
    end
    stmts
  end

  #-----------------------------------------------
  # 文 = 代入文 | もし文 | 繰り返し文 | 出力文 | {文列}
  #-----------------------------------------------
  def parse_statement
    token = get_token
    return nil if token.nil? # もうトークンが無ければ文なし

    case token
    when :print
      # 出力文: 出力 式 ;
      exp = expression
      expect(:semi, "出力文の末尾に ';' がありません")
      return [:print, exp]

    when :if
      return if_statement

    when :for
      return for_statement

    when :lbrace
      # { 文列 }
      block_stmts = []
      while true
        token = get_token
        if token == :rbrace # } でブロック終わり
          break
        else
          unget_token
          stmt = parse_statement
          if stmt
            block_stmts << stmt
          else
            raise "ブロック内で文を解析できませんでした"
          end
        end
      end
      return [:block, block_stmts]

    else
      if token.is_a?(Array) && token[0] == :var
        var_name = token[1]
        if get_token == :assign
          expr = expression
          expect(:semi, "代入文の末尾に ';' がありません")
          return [:assign, var_name, expr]
        else
          raise "代入演算子 ':=' が必要です。"
        end
      end
      unget_token
      return nil
    end
  end

  #-----------------------------------------------
  # もし文 = 'もし' 式 'ならば' 文 'そうでないなら' 文
  #-----------------------------------------------
  def if_statement
    # もし の次は 式
    exp = expression

    # 'ならば'
    expect(:then, "もし文に 'ならば' がありません")

    then_stmt = parse_statement
    raise "もし文の 'ならば' の後に文がありません" unless then_stmt

    # 'そうでないなら'
    expect(:else, "もし文に 'そうでないなら' がありません")

    else_stmt = parse_statement
    raise "もし文の 'そうでないなら' の後に文がありません" unless else_stmt

    [:if, exp, then_stmt, else_stmt]
  end

  #-----------------------------------------------
  # 繰り返し文 = '繰り返し' 式 文
  #-----------------------------------------------
  def for_statement
    exp = expression
    stmt = parse_statement
    raise "繰り返し文の後に文がありません" unless stmt
    [:for, exp, stmt]
  end

  #-----------------------------------------------
  # 式 = 項 (( '+' | '-' ) 項)*
  #-----------------------------------------------
  def expression
    result = term
    while true
      token = get_token
      case token
      when :add, :sub, :eq, :neq, :gt, :gte, :lt, :lte
        result = [token, result, term]
      else
        unget_token if token
        break
      end
    end
    p ['E', result] if Jp::DEBUG
    result
  end

  #-----------------------------------------------
  # 項 = 因子 (( '*' | '/' ) 因子)*
  #-----------------------------------------------
  def term
    result = factor
    while true
      token = get_token
      case token
      when :mul, :div, :mod
        result = [token, result, factor]
      else
        unget_token if token
        break
      end
    end
    p ['T', result] if Jp::DEBUG
    result
  end

  #-----------------------------------------------
  # 因子 = '-'? (リテラル | 変数 | '(' 式 ')' )
  #-----------------------------------------------
  def factor
    token = get_token
    minus_flg = 1
    if token == :sub
      minus_flg = -1
      token = get_token
    end

    if token.is_a? Numeric
      p ['F', token * minus_flg] if Jp::DEBUG
      token * minus_flg
    elsif token.is_a?(Array) && token[0] == :var
      var_node = [:var, token[1]]
      if minus_flg == -1
        var_node = [:mul, -1, var_node]
      end
      p ['F(var)', var_node] if DEBUG
      return var_node
    elsif token == :lpar
      result = expression
      unless get_token == :rpar
        raise Exception, "unexpected token"
      end
      p ['F', [:mul, minus_flg, result]] if Jp::DEBUG
      return [:mul, minus_flg, result]
    else
      raise Exception, "unexpected token"
    end
  end

  #================================================
  # 意味解析(Evaluator)
  #================================================
  # 抽象構文木(AST)を評価・実行
  def eval(node)
    case node
    when Array
      case node[0]
      when :assign
        # node = [:assign, var_name, exp]
        var_name = node[1]
        value = eval(node[2])
        @space[var_name] = value
        return value

      when :print
        # node = [:print, exp]
        val = eval(node[1])
        puts val
        return val

      when :if
        # [:if, exp, then_stmt, else_stmt]
        cond_val = eval(node[1])
        # 0以外なら真
        if cond_val != 0
          eval(node[2])
        else
          eval(node[3])
        end

      when :for
        # [:for, exp, stmt]
        count_val = eval(node[1])
        count_val.to_i.times do
          eval(node[2])
        end

      when :block
        # [:block, [stmts...]]
        node[1].each do |s|
          eval(s)
        end

      when :var
        var_name = node[1]
        return @space[var_name] || raise("未定義の変数: #{var_name}")

      when :add
        eval(node[1]) + eval(node[2])
      when :sub
        eval(node[1]) - eval(node[2])
      when :mul
        eval(node[1]) * eval(node[2])
      when :div
        right_val = eval(node[2])
        raise "0で割ることはできません" if right_val == 0
        eval(node[1]).to_f / right_val
      when :mod
        left_val = eval(node[1]).to_i
        right_val = eval(node[2]).to_i
        raise "0でmod(%)演算はできません" if right_val == 0
        left_val % right_val
      when :eq
        eval(node[1]) == eval(node[2]) ? 1 : 0
      when :neq
        eval(node[1]) != eval(node[2]) ? 1 : 0
      when :gt
        eval(node[1]) > eval(node[2]) ? 1 : 0
      when :gte
        eval(node[1]) >= eval(node[2]) ? 1 : 0
      when :lt
        eval(node[1]) < eval(node[2]) ? 1 : 0
      when :lte
        eval(node[1]) <= eval(node[2]) ? 1 : 0
      else
        # それ以外は未対応
        raise "未知のノードです: #{node[0]}"
      end

    when Integer, Float
      node
    else
      raise "評価不能なノードです: #{node.inspect}"
    end
  end

  #================================================
  # ヘルパー
  #================================================
  def expect(token_kind, err_msg)
    token = get_token
    raise err_msg unless token == token_kind
  end

end

Jp.new
