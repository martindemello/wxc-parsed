require 'pp'
require 'pathname'

HEADER_DIR = "wxHaskell/wxc/src/include"
 
WxClass = Struct.new(:name, :parent, :methods)
WxMethod = Struct.new(:name, :ret, :cfn, :class, :args)
WxFunction = Struct.new(:name, :ret, :cfn, :args)
WxArg = Struct.new(:type, :var)
Wx = Struct.new(:classes, :methods, :functions)

def parse_args(args)
  args.split(",").map {|i|
    a, b = i.strip.split(" ")
    WxArg.new(a, b)
  }
end

def readlines(file, wx)
  fname = Pathname(HEADER_DIR).join(file)
  return unless File.exist? fname

  IO.foreach(fname) do |line|
    # clean up inconsistencies in the input format
    line.gsub!(/\s+/, ' ')
    line.gsub!(' (', '(')

    # parse line
    if line.start_with? "/*"
      next
    elsif line =~ /^#include "(.*)"/
      readlines $1, wx
    elsif line =~ /^TClassDef\((.*)\)/
      wx.classes << WxClass.new($1, nil, [])
    elsif line =~ /^TClassDefExtend\((.*),(.*)\)/
      wx.classes << WxClass.new($1, $2, [])
    elsif line =~ /(\S+) (\S+)\(TSelf\((.*?)\) (.*?), (.*?)\);/
      ret, cfn, wxclass, obj, args = $1, $2, $3, $4, $5
      _, name = cfn.split('_')
      args = parse_args(args)
      wx.methods << WxMethod.new(name, ret, cfn, wxclass, args)
    elsif line =~ /(\S+) (\S+)\((.*?)\);/
      ret, cfn, args = $1, $2, $3
      args = parse_args(args)
      wx.functions << WxFunction.new(cfn, ret, cfn, args)
    else
      # do nothing
    end
  end
end

wx = Wx.new([], [], [])

readlines("wxc.h", wx)

pp wx
