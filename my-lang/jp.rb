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
# 戻る文 = '戻る' 式 ';'
# 関数定義 = '関数' 変数 '(' パラメータリスト ')' 文
# 式 = 項 (( '+' | '-' | '==' | '!=' | '>' | '>=' | '<' | '<=' ) 項)*
# 項 = 因子 (( '*' | '/' | '%' ) 因子)*
# 因子 = '-'? (リテラル | 変数 | '(' 式 ')' | 関数呼び出し )
# 関数呼び出し = 変数 '(' 引数リスト ')'
# パラメータリスト = (変数 (',' 変数)*)?
# 引数リスト = (式 (',' 式)*)?

class Jp
  DEBUG = false

  class Return < StandardError
    attr_reader :value

    def initialize(value)
      @value = value
    end
  end

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
      '<' => :lt,
      '関数' => :func,
      '戻る' => :return,
      ',' => :comma
    }.freeze

    # 変数・関数を管理
    @scopes = [{}]
    @functions = {}

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

    # キーワードのマッチング(演算子,予約語とか)
    @keywords.keys.each do |key|
      if @scanner.scan(Regexp.new(Regexp.escape(key)))
        return @keywords[key]
      end
    end

    # 変数名
    if (var = @scanner.scan(/\A[a-zA-Z_]\w*/))
      return [:var, var]
    end

    # 数値
    if (num = @scanner.scan(/\A\d+(\.\d+)?/))
      return num.include?('.') ? num.to_f : num.to_i
    end

    # 文字列(ダブルクォートで囲まれた部分)
    if (str = @scanner.scan(/"[^"]*"/))
      return [:string, str[1..-2]]
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
  # 文列
  #-----------------------------------------------
  def parse_statements
    stmts = []
    while (stmt = parse_statement)
      stmts << stmt
    end
    stmts
  end

  #-----------------------------------------------
  # 文
  #-----------------------------------------------
  def parse_statement
    token = get_token
    return nil if token.nil?

    case token
    when :print
      exp = expression
      expect(:semi, "出力文の末尾に ';' がありません")
      return [:print, exp]

    when :if
      return if_statement

    when :for
      return for_statement

    when :lbrace
      block_stmts = []
      while true
        token = get_token
        if token == :rbrace
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

    when :func
      return function_statement

    when :return
      return return_statement
    else
      if token.is_a?(Array) && token[0] == :var
        var_name = token[1]
        nex_token = get_token
        if nex_token == :assign
          exp = expression
          expect(:semi, "代入文の末尾に ';' がありません")
          return [:assign, var_name, exp]
        elsif nex_token == :lpar
          args = parse_arguments
          expect(:rpar, "関数呼び出しの引数リスト後に ')' がありません")
          expect(:semi, "関数呼び出し文の末尾に ';' がありません")
          return [:func_call, var_name, args]
        else
          unget_token
          nil
        end

      else
        unget_token
        nil
      end
    end
  end

  #-----------------------------------------------
  # もし文
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
  # 繰り返し文
  #-----------------------------------------------
  def for_statement
    exp = expression
    stmt = parse_statement
    raise "繰り返し文の後に文がありません" unless stmt
    [:for, exp, stmt]
  end

  #-----------------------------------------------
  # 関数
  #-----------------------------------------------
  def function_statement
    token = get_token
    raise "関数が正しく定義されていません" unless token.is_a?(Array) && token[0] == :var
    func_name = token[1]
    expect(:lpar, "関数名の後に '(' がありません")
    params = parse_parameters
    expect(:rpar, "パラメータリストの後に ')' がありません")

    [:func_def, func_name, params, parse_statement]
  end

  def return_statement
    exp = expression
    expect(:semi, "戻る文の末尾に ';' がありません")
    [:return, exp]
  end

  def parse_parameters
    params = []
    loop do
      token = get_token
      case token
      when :rpar
        unget_token
        break
      when :comma
        next
      when Array
        if token[0] == :var
          params << token[1]
        else
          raise "パラメータ名が不正です"
        end
      else
        unget_token
        break if params.empty?
        raise "パラメータリストが不正です"
      end
    end
    params
  end

  def parse_arguments
    args = []
    loop do
      arg = expression
      args << arg
      token = get_token
      if token == :comma
        next
      else
        unget_token
        break
      end
    end
    args
  end

  #-----------------------------------------------
  # 式
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
  # 項
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
  # 因子
  #-----------------------------------------------
  def factor
    token = get_token
    minus_flg = 1
    if token == :sub
      minus_flg = -1
      token = get_token
    end

    case token
    when Numeric
      token * minus_flg
    when :lpar
      result = expression
      expect(:rpar, "括弧の対応がありません")
      minus_flg == -1 ? [:mul, -1, result] : result
    when Array
      if token[0] == :var
        var_name = token[1]
        g_token = get_token
        if g_token == :lpar
          args = parse_arguments
          expect(:rpar, "関数呼び出しの引数リスト後に ')' がありません")
          node = [:func_call, var_name, args]
          minus_flg == -1 ? [:mul, -1, node] : node
        else
          unget_token
          node = [:var, var_name]
          minus_flg == -1 ? [:mul, -1, node] : node
        end
      elsif token[0] == :string
        token
      end
    else
      raise "不正な因子です: #{token.inspect}"
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
        var_name = node[1]
        value = eval(node[2])
        @scopes.last[var_name] = value
        return value

      when :print
        val = eval(node[1])
        puts val
        return val

      when :if
        cond_val = eval(node[1])
        if cond_val != 0
          eval(node[2])
        else
          eval(node[3])
        end

      when :for
        count_val = eval(node[1])
        count_val.to_i.times do
          eval(node[2])
        end

      when :block
        node[1].each do |s|
          eval(s)
        end

      when :func_def
        func_name = node[1]
        params = node[2]
        body = node[3]
        @functions[func_name] = { params: params, body: body }
        nil

      when :func_call
        func_name = node[1]
        args = node[2].map { |arg| eval(arg) }
        function = @functions[func_name] || raise("未定義の関数: #{func_name}")

        if function[:params].size != args.size
          raise "引数の数が一致しません: #{func_name}"
        end

        @scopes.push({})
        function[:params].each_with_index do |param, i|
          @scopes.last[param] = args[i]
        end

        begin
          result = eval(function[:body])
        rescue Return => ret
          result = ret.value
        ensure
          @scopes.pop
        end

        result

      when :return
        value = eval(node[1])
        raise Return.new(value)

      when :var
        var_name = node[1]
        return @scopes.last[var_name] || raise("未定義の変数: #{var_name}")

      when :string
        node[1]

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
        raise "#{node[0]}"
      end

    when Integer, Float
      node
    else
      raise "#{node.inspect}"
    end
  end

  #================================================
  # その他
  #================================================
  def expect(token_kind, err_msg)
    token = get_token
    raise err_msg unless token == token_kind
  end

end

Jp.new
