require 'pp'
require 'readline'

# First really ugly scheme interpreter implementation based on http://norvig.com/lispy.html

# An environment a Hash of var values pairs, with an outer Env
class Env < Hash

  def initialize(keys=[], vals=[], outer = nil)
    @outer = outer
    keys.zip(vals).each { |p| store(*p) }
  end

  def [](name)
    super(name) || @outer[name]
  rescue NoMethodError
    puts "Undefined symbol #{name}"
  end

  def set(name, value)
    key?(name) ? store(name, value) : @outer.set(name, value)
  end

end

#Add some scheme standard procedures to an environment
def add_globals(env)
  ops = [:+, :-, :*, :/, :>, :<, :>=, :<=, :==]
  ops.each { |op| env[op] = lambda { |a, b| a.send(op, b) } }
  env.update({
    :+       => lambda { |*xs| eval xs.join('+') },
    :*       => lambda { |*xs| eval xs.join('*') },
    :length  => lambda { |x| x.length},
    :cons    => lambda { |x,y| [x] + y},
    :car     => lambda { |x| x[0] },
    :cdr     => lambda { |x| x[1..-1] },
    :append  => lambda { |x| x + y },
    :list    => lambda { |*xs| xs },
    :list?   => lambda { |x| x.is_a? Array },
    :null?   => lambda { |x| x == nil },
    :symbol? => lambda { |x| x.is_a? Symbol },
    :not     => lambda { |x| !x },
    :display => lambda { |x| p x },
    :quit    => lambda { exit 1 }
  })
end

$global_env = add_globals(Env.new)

def reval(x, env=$global_env)
  return env[x] if x.is_a? Symbol # Variable reference
  return x if !x.is_a? Array      # Constant literal
  case x[0]
    when :quote, :"'" then x[1..-1]      # (quote exp)
    when :if                      # (if test conseq alt)
      _, test, conseq, alt = x
      reval(reval(test, env) ? conseq : alt, env)
    when :set! then env.set(x[1], reval(x[2], env)) # (set! var exp)
    when :define # (define var exp)
      _, var, exp = x
      env[var] = reval(exp, env)
    when :lambda                                        # (lambda (var*) exp)
      _, vars, exp = x
      Proc.new { |*args| reval(exp, Env.new(vars, args, env)) }
    when :begin                                    # (begin exp*)
      x[1..-1].inject([nil, env]) { |val_env, exp| [reval(exp, val_env[1]), val_env[1]]}[0]
    when :env
      pp env
    else                                           # (proc exp*)
      exps = x.map { |exp| reval(exp,env) }
      return exps[0] if !exps[0].is_a? Proc
      exps[0].call(*exps[1..-1])
  end
end

# Read a Scheme expression from a string.
def read(s)
  read_from(tokenize(s))
end

# Read an expression from a sequence of tokens.
def read_from(tokens)
  raise SyntaxError, 'Unexpected EOF while reading' if tokens.size == 0
  token = tokens.delete_at(0)
  if '(' == token
    list = []
    while tokens[0] != ')'
      list << read_from(tokens)
    end
    tokens.delete_at(0)
    list
  elsif ')' == token
    raise SyntaxError 'Unexpected )'
  else
    atom(token)
  end
end

# Convert a string into a list of tokens
def tokenize(src)
  src.gsub('(', ' ( ').gsub(')', ' ) ').split
end

# Numbers become numbers; every other token is a symbol
def atom(token)
  Integer(token)
rescue ArgumentError
  begin
    Float(token)
  rescue ArgumentError
    token.to_sym
  end
end

# Convert a Ruby object back into a Lisp-readable string.
def to_lisp_string(exp)
  if exp.kind_of? Array
    "(" + exp.map { |x| to_lisp_string(x) + " " }.join[0..-2] + ")"
  else
    exp.to_s
  end
end

# A prompt-read-eval-print loop.
def repl(prompt='ris.py> ')
  puts "Welcome to Rispy (Scheme interpreter) version 0.0.1 based on Peter's Norvig: 'How to write a Lisp interpreter in Python'"
  puts Time.now
  while line = Readline.readline(prompt, true)
    to_eval = read(line)
    p to_eval
    val = reval(to_eval)
    puts to_lisp_string(val) if val
  end
end

# if ARGV.size > 0
#   src = open(ARGV[0], 'r'){|f| f.read }
#   p(eval(parse(src), add_globals(Env.new)))
# else
#   print "usage: rispy.rb file.scm\n"
# end

repl
