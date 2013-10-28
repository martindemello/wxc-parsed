require 'pp'
require 'pathname'

HEADER_DIR = "wxHaskell/wxc/src/include"
 
WxClass = Struct.new(:name, :parent, :methods)
WxMethod = Struct.new(:name, :ret, :cfn, :classname, :args)
WxFunction = Struct.new(:name, :ret, :cfn, :args)
Wx = Struct.new(:classes, :methods, :functions)
WxSelf = Struct.new(:type)

class WxArg < Struct.new(:type, :var, :is_open)
  def close(args)
    case type
    when :class
      raise "bad class" if args.length != 1
      self.type = args[0]
      self.is_open = false
    when :self
      raise "bad class" if args.length != 1
      self.type = WxSelf.new(args[0])
      self.is_open = false
    else
    end
  end

  def +(other)
    if other != "*" || self.var != nil
      raise "whatyousay"
    else
      self.type + "*"
    end
  end

  def to_str
    inspect
  end

  def inspect
    "[" + self.type.inspect + " " + self.var.inspect + "]"
  end
end

class WxCompositeArg < Struct.new(:type, :fields, :is_open)
  def close(args)
    self.fields = args
    self.is_open = false
  end

  def inspect
    "{" + self.fields.map {|x| self.type + "." + x}.join(", ") + "}"
  end
end

class WxArgList < Struct.new(:args, :is_open)
  def close(args)
    args.each do |arg|
      a = self.args.last
      if (a.is_a? WxArg) && a.var.nil?
        a.var = arg
      elsif (a.is_a? String)
        self.args.pop
        self.args.push WxArg.new(a, arg, false)
      else
        self.args.push arg
      end
    end
    self.is_open = false
  end
end

def close(stack)
  args = []
  while true
    a = stack.pop
    if (a.respond_to? :is_open) && a.is_open
      if a.respond_to? :close
        a.close(args)
      end
      stack.push a
      break
    elsif a == ")"
      stack.push(WxArgList.new([], false))
    else
      args.unshift(a)
    end
  end
end

def parse_fn(tokens)
  stack = []
  tokens.each do |t|
    case t
    when '*'
      stack.push(stack.pop + t)
    when '('
      case stack.last
      when 'TClass'
        stack.pop
        stack.push(WxArg.new(:class, nil, true))
      when 'TSelf'
        stack.pop
        stack.push(WxArg.new(:self, nil, true))
      when /^T[A-Z]/
        stack.push(WxCompositeArg.new(stack.pop, [], true))
      else
        stack.push(WxArgList.new([], true))
      end
    when ')'
      close(stack)
    when ',', ';'
      # ignore
    else
      stack.push(t)
    end
  end
  stack
end

def parse_line(tokens, wx)
  case tokens.first
  when 'TClassDef'
    # ["TClassDef", "(", "Class", ")"]
    wx.classes << WxClass.new(tokens[2], nil, [])
  when 'TClassDefExtend'
    # ["TClassDefExtend", "(", "Class", ",", "Parent", ")"]
    wx.classes << WxClass.new(tokens[2], tokens[4], [])
  else
    ret, fname, args = parse_fn tokens
    if ret.is_a? WxArg
      # TODO: see what this implies
      if ret.type.is_a? WxSelf
        ret = ret.type.type
      else
        ret = ret.type
      end
    end
    args = args.args
    if (!args.empty?) && (args.first.type.is_a? WxSelf)
      this, rest = args
      # there are a few cases where the fname prefix is not the class
      _, name = fname.split(/_/)
      m = WxMethod.new
      m.name = name
      m.ret = ret
      m.cfn = fname
      m.classname = this.type.type
      m.args = rest
      wx.methods << m
    else
      f = WxFunction.new
      f.name = f.cfn = fname
      f.ret = ret
      f.args = args
      wx.functions << f
    end
  end
end

def readlines(file, wx)
  fname = Pathname(HEADER_DIR).join(file)
  return unless File.exist? fname

  IO.foreach(fname) do |line|
    line.chomp!

    # parse line
    if line.start_with? "/*"
      next
    elsif line =~ /^#include "(.*)"/
      readlines $1, wx
    elsif not ((line.start_with? 'TClass') or (line.end_with? ';'))
      next
    else
      tokens = line.scan(/\s+|\w+|[[:punct:]]/).map(&:strip).reject {|i| i.empty?}
      # special case this
      tokens.shift if tokens.first == 'EXPORT'
      parse_line tokens, wx
    end
  end
end

if __FILE__ == $0
  wx = Wx.new([], [], [])
  readlines("wxc.h", wx)
  c = {}
  wx.classes.each {|i| c[i.name] = i}
  wx.methods.each {|i| c[i.classname].methods << i }
  pp wx.classes
end
