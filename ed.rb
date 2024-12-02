class Ed
  def initialize()
    @buffer = []
    @output = ""
    @current = 1

    begin
      if ARGV.empty?
        raise "No such file"
      end
      @buffer = ARGF.readlines.map(&:chomp)
      @current = @buffer.size if @buffer.size > 0 # カレント行を最後の行に設定
      bytes = @buffer.join("\n").bytesize
      @output = "#{bytes}\n"
    rescue
      @output = "?"
    end
    _print

    loop do
      read
      eval
      _print
    end
  end

  def read
    @command = STDIN.gets
    @command = @command.chomp if @command # 改行をなくす
  end

  def eval
    @output = ""

    begin
      # 正規表現でコマンド解析
      addr = '(?:\d+|[.$,;]|\/.*\/)'
      cmnd = '(?:wq|[acdijnpqrw=]\z|)'
      prmt = '(?:.*)'
      pattern = /\A(#{addr}(,#{addr})?)?(#{cmnd})(#{prmt})?\z/
      if @command =~ pattern
        full_address = $1
        cmd = $3
        params = $4

        # アドレスを分割
        if full_address
          if full_address.include?(',')
            addr1_str, addr2_str = full_address.split(',', 2)
          else
            addr1_str = full_address
            addr2_str = nil
          end
        else
          addr1_str = addr2_str = nil
        end

        # addr1,2を数値へ変換
        addr1 = address_to_i(addr1_str)
        addr2 = address_to_i(addr2_str)

        # プリントデバッグ
        # puts "fulladdress: #{full_address}"
        # puts "cmd: #{cmd}"
        # puts "params: #{params}"
        # puts "addr1: #{addr1}"
        # puts "addr2: #{addr2}"

        # コマンドの処理
        case cmd
        when "q"
          if full_address || (params && !params.empty?)
            raise ArgumentError
          else
            exit
          end
        when "p", "n"
          # 引数が正しいか判定(パラメーターが指定されたらエラー)
          if params && !params.empty?
            raise ArgumentError
          end

          # ","のみ指定ならばすべての行を出力
          if full_address == ","
            addr1 = 1
            addr2 = @buffer.size
          end

          if addr1.nil? && addr2
            addr1 = 1
          end

          # アドレスが未指定の場合、デフォルトアドレスであるカレント行を設定
          addr1 = @current if addr1.nil?
          addr2 = @current if addr2.nil?

          # アドレスが正しいか判定
          if !(valid_address?(addr1) && valid_address?(addr2)) || addr1 > addr2
            raise IndexError
          end

          (addr1..addr2).each do |addr|
            if cmd == "p"
              @output << "#{@buffer[addr - 1]}\n"
            else
              @output << "#{addr} #{@buffer[addr - 1]}\n"
            end
          end
          @current = addr2 # カレントを出力した最終行に設定
        when "d"
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
        when "="
          # アドレスが未指定の場合、デフォルトアドレスであるカレント行を設定
          addr1 = @buffer.size if addr1.nil?

          # アドレスが正しいか判定
          unless valid_address?(addr1)
            raise IndexError
          end

          # 指定された行の行番号をoutputへ
          @output << "#{addr1}\n"
        when ""
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
            unless valid_address?(@current+1)
              raise IndexError
            end
            @current += 1
            @output << "#{@buffer[@current - 1]}\n"
          end
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
end

Ed.new