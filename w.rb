#!/usr/bin/ruby1.8

# whitepsace-ruby
# Copyright (C) 2003 by Wayne E. Conrad
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA

Opcodes = [
  ['  ', :push, :signed],
  [' \n ', :dup],
  [' \t ', :dupnum, :unsigned],
  [' \n\t', :swap],
  [' \n\n', :discard],
  [' \t\n', :discardnum, :unsigned],
  ['\t   ', :add],
  ['\t  \t', :sub],
  ['\t  \n', :mul],
  ['\t \t ', :div],
  ['\t \t\t', :mod],
  ['\t\t ', :store],
  ['\t\t\t', :retrieve],
  ['\n  ', :label, :unsigned],
  ['\n \t', :call, :unsigned],
  ['\n \n', :jump, :unsigned],
  ['\n\t ', :jz, :unsigned],
  ['\n\t\t', :jn, :unsigned],
  ['\n\t\n', :ret],
  ['\n\n\n', :exit],
  ['\t\n  ', :outchar],
  ['\t\n \t', :outnum],
  ['\t\n\t ', :readchar],
  ['\t\n\t\t', :readnum],
]

def error(message)
  $stderr.puts "Error: #{message}"
  exit 1
end

class Tokenizer

  attr_reader :tokens

  def initialize source = nil
    @tokens = []
    if source.nil? || !(source.is_a?(String))
      source = ARGV[0]
    end
    begin
      file = File.open(source)
    rescue
      file = $<
    end
    @program = file.read.tr("^ \t\n", "")
    while @program != "" do
      @tokens << tokenize
    end
  end

  private

  def tokenize
    for ws, opcode, arg in Opcodes
      if @program =~ /\A#{ws}#{arg ? '([ \t]*)\n' : '()'}(.*)\z/m
        @program = $2
        case arg
        when :unsigned
          return [opcode, eval("0b#{$1.tr(" \t", "01")}")]
        when :signed
          value = eval("0b#{$1[1..-1].tr(" \t", "01")}")
          value *= -1 if ($1[0] == ?\t)
          return [opcode, value]
        else
          return [opcode]
        end
      end
    end
    error("Unknown command: #{@program.tr(" \t\n", "STL")}")
  end

end

class Executor

  def initialize(tokens)
    @tokens = tokens
    # whether or not to output transform result to trans
    @release = true
    if !@release
      @trans = open("trans", "w")
    end
  end

  def run
    @pc = 0	#Program pointer
    @stack = []
    @heap = {}
    @callStack = []
    loop do
      opcode, arg = @tokens[@pc]
      @pc += 1
      case opcode
      when :push
        @stack.push arg
        debug "push " + arg.to_s
      when :label
        debug "label " + arg.to_s
      when :dup
        @stack.push @stack[-1]
        debug "dup"
      when :dupnum
        debug "dupnum " + arg.to_s
        break if arg == 0
        if @stack.size-arg < 0
          error("Stack underflow in dup")
        end
        @stack.push @stack[-arg]
      when :outnum
        print @stack.pop
        debug "outnum"
      when :outchar
        print @stack.pop.chr
        debug "outchar"
      when :add
        binaryOp("+")
        debug "add"
      when :sub
        binaryOp("-")
        debug "sub"
      when :mul
        binaryOp("*")
        debug "mul"
      when :div
        binaryOp("/")
        debug "div"
      when :mod
        binaryOp("%")
        debug "mod"
      when :jz
        debug "jz " + arg.to_s
        jump(arg) if @stack.pop == 0
      when :jn
        debug "jn " + arg.to_s
        jump(arg) if @stack.pop < 0
      when :jump
        debug "jump " + arg.to_s
        jump(arg)
      when :discard
        @stack.pop
        debug "discard"
      when :discardnum
        debug "discardnum " + arg.to_s
        break if arg == 0
        if @stack.size-arg <= 0
          error("Stack underflow in discard")
        end
        @stack[@stack.size-arg-1..-2] = nil
        @stack.delete_at(-2)
      when :exit
        debug "exit"
        if !@release
          @trans.close
        end
        exit
      when :store
        value = @stack.pop
        address = @stack.pop
        @heap[address] = value
        debug "store"
      when :call
        debug "call " + arg.to_s
        @callStack.push(@pc)
        jump(arg)
      when :retrieve
        @stack.push @heap[@stack.pop]
        debug "retrieve"
      when :ret
        @pc = @callStack.pop
        debug "pop"
      when :readchar
        debug "readchar"
        @heap[@stack.pop] = $stdin.getc
      when :readnum
        debug "readnum"
        @heap[@stack.pop] = $stdin.gets.to_i
      when :swap
        @stack[-1], @stack[-2] = @stack[-2], @stack[-1]
        debug "swap"
      else
        error("Unknown opcode: #{opcode.tr(" \t\n", "STL")}")
      end
    end
  end

  private

  def binaryOp(op)
    b = @stack.pop
    a = @stack.pop
    @stack.push eval("a #{op} b")
  end

  def jump(label)
    @tokens.each_with_index do |token, i|
      if token == [:label, label]
        @pc = i
        return
      end
    end
    error("Unknown label: #{label}")
  end

  def debug(msg)
    if !@release
      @trans.puts msg
    end
  end

end

if __FILE__ == $0
  Executor.new(Tokenizer.new.tokens).run
end