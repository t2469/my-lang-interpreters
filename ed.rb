class Ed
  DEBUG = false

  def initialize()
    @buffer = []
    @output = ""
    @current = 1
    @mode = :command
    @temp_buffer = [] # insertモード時の入力を保存する

    begin
      if ARGV.empty?
        raise "NoSuchFile"
      end
      @file = ARGV[0]
      @buffer = ARGF.readlines.map(&:chomp)
      @current = @buffer.size if @buffer.size > 0 # カレント行を最後の行に設定
      bytes = @buffer.join("\n").bytesize
      @output = "#{bytes}\n"
      _print
    rescue
      @output = "No such file"
      _print
      exit
    end

    loop do
      _read
      _eval
      _print
    end
  end

  def _read
    @command = STDIN.gets
    @command = @command.chomp if @command # 改行をなくす
  end

  def _eval
    @output = ""

    begin
      if @mode == :command
        # 正規表現でコマンド解析
        addr = '(?:\d+|[.$,;]|\/.*\/)'
        cmnd = '(?:wq|[acdijnpqrw=]\z|)'
        prmt = '(?:.*)'
        pattern = /\A(#{addr}(,#{addr})?)?(#{cmnd})(#{prmt})?\z/
        if @command =~ pattern
          full_address = $1
          cmd = $3
          params = $4
          addr1, addr2 = parse_address(full_address)

          # プリントデバッグ
          puts "full_address: #{full_address}" if DEBUG
          puts "cmd: #{cmd}" if DEBUG
          puts "params: #{params}" if DEBUG
          puts "addr1: #{addr1}" if DEBUG
          puts "addr2: #{addr2}" if DEBUG
        end
        # 動的ディスパッチでコマンドの実行
        self.send("command_#{cmd}", full_address, addr1, addr2, params)
      elsif @mode == :insert
        if @command == "."
          @buffer = @buffer[0...@insert_position] + @temp_buffer + @buffer[@insert_position..-1]
          @current = @insert_position + @temp_buffer.size
          @temp_buffer = []
          @mode = :command
        else
          @temp_buffer << @command
        end
      end
    rescue
      @output = "?"
    end
  end

  def _print
    puts @output unless @output.empty?
  end

  def valid_address?(addr)
    1 <= addr && addr <= @buffer.size
  end

  def parse_address(full_address)
    return [nil, nil] unless full_address

    addr1_str, addr2_str = full_address.split(',', 2)
    addr1 = address_to_i(addr1_str)
    addr2 = address_to_i(addr2_str)
    [addr1, addr2]
  end

  def address_to_i(addr)
    return nil if addr.nil?
    case addr
    when /\A\d+\z/
      addr.to_i
    when '.'
      @current
    when '$'
      @buffer.size
    end
  end

  def command_a(full_address, addr1, addr2, params)
    puts "command_aの実行"
    addr = addr1 || @current

    unless valid_address?(addr)
      raise IndexError
    end

    @insert_position = addr # 挿入位置は次の行
    @mode = :insert
    @temp_buffer = []
  end

  def command_q(full_address, addr1, addr2, params)
    if full_address || (params && !params.empty?)
      raise ArgumentError
    else
      exit
    end
  end

  def command_w(full_address, addr1, addr2, params)
    data = @buffer.join("\n")
    bytes = File.write(@file, data)
    @output = "#{bytes}\n"
  end

  def command_wq(full_address, addr1, addr2, params)
    command_w(full_address, addr1, addr2, params)
    command_q(full_address, addr1, addr2, params)
  end

  def command_print(full_address, addr1, addr2, params, include_line_number: false)
    raise ArgumentError, "This command does not accept parameters." if params && !params.empty?

    if full_address == ","
      addr1 = 1
      addr2 = @buffer.size
    else
      addr1, addr2 = parse_address(full_address)
    end

    addr1 ||= @current
    addr2 ||= @current

    raise IndexError, "Invalid address range." unless valid_address?(addr1) && valid_address?(addr2) && addr1 <= addr2

    (addr1..addr2).each do |addr|
      line = @buffer[addr - 1]
      @output << (include_line_number ? "#{addr} #{line}\n" : "#{line}\n")
    end

    @current = addr2
  end

  def command_p(full_address, addr1, addr2, params)
    command_print(full_address, addr1, addr2, params, include_line_number: false)
  end

  def command_n(full_address, addr1, addr2, params)
    command_print(full_address, addr1, addr2, params, include_line_number: true)
  end

  def command_d(full_address, addr1, addr2, params)
    # アドレスが未指定の場合、デフォルトアドレスであるカレント行を設定
    addr1 = @current if addr1.nil?
    addr2 = @current if addr2.nil?

    # アドレスが正しいか判定
    if !(valid_address?(addr1) && valid_address?(addr2)) || addr1 > addr2
      raise IndexError
    end

    # 要素の削除
    @buffer.slice!(addr1 - 1..addr2 - 1)
    @current = [addr1 - 2, 1].max # 削除された範囲の1つ手前の行をカレントとする。ただし、currentが1より小さくならないように処理
  end

  def command_=(full_address, addr1, addr2, params)
    # アドレスが未指定の場合、デフォルトアドレスであるカレント行を設定
    addr1 = @buffer.size if addr1.nil?

    # アドレスが正しいか判定
    unless valid_address?(addr1)
      raise IndexError
    end

    # 指定された行の行番号をoutputへ
    @output << "#{addr1}\n"
  end

  def command_(full_address, addr1, addr2, params)
    if addr1
      # カレント行変更

      unless valid_address?(addr1)
        raise IndexError
      end
      # 正しいアドレスかを判定し、addr2を優先
      if addr2
        unless valid_address?(addr2)
          raise IndexError
        end
        addr1 = addr2
      end

      @current = addr1
      @output << "#{@buffer[addr1 - 1]}\n"
    else
      # 改行コマンド
      # 正しい範囲内か判定
      unless valid_address?(@current + 1)
        raise IndexError
      end
      @current += 1
      @output << "#{@buffer[@current - 1]}\n"
    end
  end
end

Ed.new